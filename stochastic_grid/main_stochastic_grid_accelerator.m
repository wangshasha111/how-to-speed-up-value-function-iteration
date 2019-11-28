% Homework 1 Econ714 JFV
% A two good production economy
% Written by Shasha Wang
% Reference: Rust 1997

% Implement a stochastic grid scheme (Rust, 1997) for a Value function iteration,
% with 500 vertex points with a coverage of +-25% of kss (you can keep the grid of investment fixed).
% Compare accuracy and computing time between the simple grid scheme implemented in 2) 
% and the results from the multigrid scheme. 
% Present evidence to support your claims.

%% Value Function Iteration with Stochastic grid and Accelerator

% Revised based on ..\main_accelerator.m
% Even though through experiment I found out that Stochastic grid with
% accelerator won't converge, I keep the algorithm for future tries. 
% To NOT use the accelerator, 
%                 if mod(iteration,10) >=0 
% To use the accelerator,
%                 if mod(iteration,10) ==1 

%% Algorithm explained
% The Random Bellman operator (RBO) is a mapping 
% where next period states are N states randomly chosen from all states.
% Keep the points chosen fixed for iterations till convergence.

% Note when computing the expected value, we need to use
% CONDITIONAL PROBABILITY - conditional on that the N states are chosen, i.e., we need
% to divide each transition probability by the sum of the transition probability of N chosen states

% ==============================================================

% The way to draw random numbers

% FIRST step: set up the seed

% stochastic_grid=rng;
% rng(stochastic_grid)

% SECOND step: use randperm to generate unique integers. Don't use randi,
% since numbers won't be unique.
% p = randperm(n,k) returns a ROW vector containing k unique integers selected randomly from 1 to n inclusive.
% X = randi(imax) returns a pseudorandom scalar integer between 1 and imax.
% X = randi(imax,sz1,...,szN) returns an sz1-by-...-by-szN array where sz1,...,szN indicates the size of each dimension. For example, randi(10,3,4) returns a 3-by-4 array of pseudorandom integers between 1 and 10.

% ==============================================================
% Grid Search VS fminsearch
% In the value function iteration, I used grid search instead of linear
% interpolation, because I can't randomize tomorrow's state using
% fminsearch/con/bnd. 
% Because we are doing grid search, CONCAVITY of value function and
% MONOTONICITY of policy function can be utilized to speed up the process.
% NOTE: we also have to deal with COMPLEX solutions for fsolve when we use
% grid search

% ==============================================================

main_setup % parameters, shocks

%% Value function iteration

% As in the fixed-grid problem, we also first set labor level to steady
% state level and compute a converged value function, then use it as the
% initial guess for the real and qualified value function iteration. 

%% Step 1: Compute the Steady State

% Use fsolve to solve the system of equations
    
input_ss_initial=[0.9,0.2,0.5];
opts1 = optimoptions('fsolve','Tolx',1e-6, 'Display','iter');

display('Start Solving the Function');
SS = fsolve(@(input_ss) steadyStateFunction(input_ss,bbeta,ddelta,aalphaK,aalphaL,mmu_1,mmu_2), input_ss_initial,opts1);
display('Solution Obtained.');
kSteadyState = SS(1);
labor_1_SteadyState = SS(2);
labor_2_SteadyState = SS(3);
fprintf('The Candidate Solution Is Found to Be: %2.4f \n', SS);
fprintf('The Function Value At this Candidate Solution Is: %2.6f \n', ...
        steadyStateFunction(SS,bbeta,ddelta,aalphaK,aalphaL,mmu_1,mmu_2));

consumption_1_SteadyState = consumptionFunction1(1,kSteadyState,kSteadyState,labor_1_SteadyState,aalphaK,aalphaL,ddelta);
consumption_2_SteadyState = consumptionFunction2(1,labor_2_SteadyState);
utilitySteadyState = utilityFunction(consumption_1_SteadyState,consumption_2_SteadyState,labor_1_SteadyState,labor_2_SteadyState,mmu_1,mmu_2);

T = table(kSteadyState,labor_1_SteadyState,labor_2_SteadyState,consumption_1_SteadyState,consumption_2_SteadyState)

%% Step 2: set up k grid around the steady state

kSpread = 0.25;
kMax = kSteadyState * (1 + kSpread);
kMin = kSteadyState * (1 - kSpread);
Nk = 500;
vGrid_k = linspace(kMin,kMax,Nk)';
inputs.vGrid_k = vGrid_k;

%% Step 3. Pre-Iteration: Set labor to steady state

%% Draw random grid points

% Most generally, we should draw random draws from all possible states, i.e., CAPITAL * SHOCKS.
% If we have 500 points for capital, 15 points for shocks, then altogether
% we have 7500 states, from which we draw.

% But we are told in the homework that the grid for capital should be fixed. 
% And we only have two dimensions of shocks. 
% That means the other dimension also needs to be fixed. 
% So we are going to take draws from different level of capital as well as from different shocks.

NkDraws = ceil(Nk/50);
seedKDraws=rng;
rng(seedKDraws);
ikStochasticGrid = randperm(Nk,NkDraws);%a ROW vector containing numberOfDraws unique integers selected randomly from 1 to Nk inclusive.
ikStochasticGrid = sort(ikStochasticGrid);

NaDraws = ceil(Na/2);
seedADraws=rng;
rng(seedADraws);
iaStochasticGrid = randperm(Na,NaDraws);%a ROW vector containing numberOfDraws unique integers selected randomly from 1 to Nk inclusive.
iaStochasticGrid = sort(iaStochasticGrid);

% Get the probability matrix for the random draws
mProb_a1a2StochasticGrid = zeros(Na,Na);
for iaPrime = iaStochasticGrid
     mProb_a1a2StochasticGrid(:,iaPrime) = mProb_a1a2(:,iaPrime);
end
% Then normalize it to a proper probability matrix
mProb_a1a2StochasticGrid = mProb_a1a2StochasticGrid./sum(mProb_a1a2StochasticGrid,2);

%% Required matrices and vectors for Pre-Iteration

mValue0                 = utilitySteadyState.*ones(Nk,Na); inputs.mValue0 = mValue0;
mValue                  = zeros(Nk,Na);
mKPolicy                = zeros(Nk,Na);
% mLaborPolicy_1          = zeros(Nk,Na);
% mLaborPolicy_2          = zeros(Nk,Na); 
mConsumptionPolicy_1    = zeros(Nk,Na);
mConsumptionPolicy_2    = zeros(Nk,Na);

maxIter = 10000;
tolerance = 1e-6;

iteration = 1;
mDifference = zeros(maxIter,1);
mDifference(iteration) = 100;

options = optimset('Display', 'off');
% opts1 = optimoptions('fsolve','Tolx',1e-6, 'Display','off');
% laborInitial=[labor_1_SteadyState,labor_2_SteadyState];

tic

% Finding value and policy functions numerically
while iteration <= maxIter  ...% make sure the last iteration does the maximization
        && ( (mDifference(iteration) > tolerance)  | (mDifference(iteration) <= tolerance && mod(iteration,10)~=2)) 
        
    expectedValue0 = mValue0 * mProb_a1a2StochasticGrid';% row: kPrime, column: a, i.e., expected value if today's shock is a and I choose k as tomorrow's capital stock

    if (mDifference(iteration) > tolerance)    
        for ia = 1:Na
            a_1 = mGrid_a1a2(ia,1);
            a_2 = mGrid_a1a2(ia,2);
            
            iikPrime = 1;
%             normalizedExpectedValue0 = expectedValue0(:,ia)/vNormalizer(ia); % Nk by 1 colum vector

            for ik = 1:Nk
                k = vGrid_k(ik);
  
%                 if mod(iteration,10) ==1 % do maximization
                if mod(iteration,10) >=0 % do maximization
                    
                    valueHighSoFar = -1000.0;
                    kChoice  = vGrid_k(1);
            
                    for ikPrime = ikStochasticGrid(iikPrime:end)
                        kPrime = vGrid_k(ikPrime);
                        [valueProvisional,consumption_1,consumption_2] = valueFunction_stochasticGrid_setLaborToSteadyState...
                            (kPrime,ikPrime,ik,k,ia,a_1,a_2,expectedValue0,bbeta,mmu_1,mmu_2,ddelta,aalphaK,aalphaL,labor_1_SteadyState,labor_2_SteadyState);
%                         valueProvisional = outputValueFunction(1);
%                         consumption_1 = outputValueFunction(2);
%                         consumption_2 = outputValueFunction(3);
                        if (valueProvisional>valueHighSoFar)
                            valueHighSoFar = valueProvisional;
                            kChoice = vGrid_k(ikPrime);
                            iikPrime = sum(ikPrime >= ikStochasticGrid);
                        else
                            break
                        end
                    end
               
                    mValue(ik,ia) = valueHighSoFar;
                    mKPolicy(ik,ia) = kChoice;
                    mConsumptionPolicy_1(ik,ia) = consumption_1;
                    mConsumptionPolicy_2(ik,ia) = consumption_2;

                else % accelerator
                    currentUtility = utilityFunction(mConsumptionPolicy_1(ik,ia),mConsumptionPolicy_2(ik,ia),labor_1_SteadyState,labor_2_SteadyState,mmu_1,mmu_2);
                    expectedValue = expectedValue0(sum(mKPolicy(ik,ia)>=vGrid_k),ia);
                    value = (1-bbeta)*currentUtility + bbeta * expectedValue;
                    mValue(ik,ia) = value;
                end
            end
        end
        
        iteration = iteration + 1;
        mDifference(iteration) = max(abs(mValue - mValue0),[],'all');
        mValue0         = mValue;

        if mod(iteration,10) == 2
            fprintf(' Iteration: %2.0f, Sup diff: %2.8f\n', iteration-1, mDifference(iteration)); 
        end
        
    else

        for ia = 1:Na
            a_1 = mGrid_a1a2(ia,1);
            a_2 = mGrid_a1a2(ia,2);
            iikPrime = 1;

            for ik = 1:Nk
                k = vGrid_k(ik);
                
                valueHighSoFar = -1000.0;
                kChoice  = vGrid_k(1);

                for ikPrime = ikStochasticGrid(iikPrime:end)
                    kPrime = vGrid_k(ikPrime);
                    [valueProvisional,consumption_1,consumption_2] = valueFunction_stochasticGrid_setLaborToSteadyState...
                        (kPrime,ikPrime,ik,k,ia,a_1,a_2,expectedValue0,bbeta,mmu_1,mmu_2,ddelta,aalphaK,aalphaL,labor_1_SteadyState,labor_2_SteadyState);
%                     valueProvisional = outputValueFunction(1);
%                     consumption_1 = outputValueFunction(2);
%                     consumption_2 = outputValueFunction(3);
                    if (valueProvisional>valueHighSoFar)
                        valueHighSoFar = valueProvisional;
                        kChoice = vGrid_k(ikPrime);
                        iikPrime = sum(ikPrime >= ikStochasticGrid);
                    else
                        break
                    end
                end

                mValue(ik,ia) = valueHighSoFar;
                mKPolicy(ik,ia) = kChoice;
                mConsumptionPolicy_1(ik,ia) = consumption_1;
                mConsumptionPolicy_2(ik,ia) = consumption_2;                

            end
        end
        
        iteration = iteration + 1;
        mDifference(iteration) = max(abs(mValue - mValue0),[],'all');
        mValue0         = mValue;

        fprintf(' Iteration: %2.0f, Sup diff: %2.8f\n', iteration-1, mDifference(iteration)); 
        
        if mDifference(iteration) <= tolerance
            break
        end
    end

end

toc

fprintf(' Convergence achieved. Total Number of Iteration: %2.0f, Sup diff: %2.8f\n', iteration-1, mDifference(iteration)); 

save ShashaWang_JFV_PS1_500_stochastic_capital_grid_points_valueFunctionIteration_setLaborToSteadyState

%  My computer, without accelerator
%  Iteration:  1, Sup diff: 0.00473112
%  Iteration: 11, Sup diff: 0.00036681
%  Iteration: 21, Sup diff: 0.00022816
%  Iteration: 31, Sup diff: 0.00014992
%  Iteration: 41, Sup diff: 0.00009946
%  Iteration: 51, Sup diff: 0.00006610
%  Iteration: 61, Sup diff: 0.00004394
%  Iteration: 71, Sup diff: 0.00002921
%  Iteration: 81, Sup diff: 0.00001942
%  Iteration: 91, Sup diff: 0.00001291
%  Iteration: 101, Sup diff: 0.00000858
%  Iteration: 111, Sup diff: 0.00000571
%  Iteration: 121, Sup diff: 0.00000379
%  Iteration: 131, Sup diff: 0.00000252
%  Iteration: 141, Sup diff: 0.00000168
%  Iteration: 151, Sup diff: 0.00000111
%  Iteration: 155, Sup diff: 0.00000095
% ��ʱ 24.143055 �롣
%  Convergence achieved. Total Number of Iteration: 155, Sup diff: 0.00000095

%% Then do the regular Value Function Iteration using value function calculated above as the first guess
% 
% % Because we are now using grid search, it's reasonable to use efficiency
% % matrix since we don't need to do interpolation
% 
% % Logic: 
% % Because fsolve takes a long time in iteration to solve for labor_1,
% % labor_2, I create the matrices for them as well as for consumption_1 and
% % consumption_2 to retrieve from later.
% 
% 
% mLabor_1Fsolve = zeros(Nk,Nk,Na); % kPrime,k,[a_1,a_2]
% mLabor_2Fsolve = zeros(Nk,Nk,Na);
% mConsumption_1Fsolve = zeros(Nk,Nk,Na);
% mConsumption_2Fsolve = zeros(Nk,Nk,Na);
% mCurrentUtilityFsolve = zeros(Nk,Nk,Na);
% laborInitial=[labor_1_SteadyState,labor_2_SteadyState];
% opts1 = optimoptions('fsolve','Tolx',1e-6, 'Display','off');
% 
% tic
% for ia = 1:Na
%     a_1 = mGrid_a1a2(ia,1);
%     a_2 = mGrid_a1a2(ia,2);
%     
%     for ik = 1:Nk
%         k = vGrid_k(ik);
%         
%         for ikPrime = ikStochasticGrid
%             kPrime = vGrid_k(ikPrime);
%             
%             vLaborFsolve = fsolve(@(labor) laborFunction(labor,a_1,a_2,k,kPrime,mmu_1,mmu_2,aalphaK,aalphaL,ddelta), laborInitial,opts1);
% 
%             mLabor_1Fsolve(ikPrime,ik,ia) = vLaborFsolve(1);
%             mLabor_2Fsolve(ikPrime,ik,ia) = vLaborFsolve(2);
%             mConsumption_1Fsolve(ikPrime,ik,ia) = consumptionFunction1(a_1,k,kPrime,vLaborFsolve(1),aalphaK,aalphaL,ddelta);
%             mConsumption_2Fsolve(ikPrime,ik,ia) = consumptionFunction2(a_2,vLaborFsolve(2));
%             mCurrentUtilityFsolve(ikPrime,ik,ia) = utilityFunction(mConsumption_1Fsolve(ikPrime,ik,ia),mConsumption_2Fsolve(ikPrime,ik,ia),vLaborFsolve(1),vLaborFsolve(2),mmu_1,mmu_2);
% %             mMarginalUtilityTodayFsolve(ikPrime,ia,ik) = mmu_1 * (mConsumption_2Fsolve(ikPrime,ia,ik))^mmu_2 * (mConsumption_1Fsolve(ikPrime,ia,ik))^(mmu_1-1);
% %             laborInitial=[vLaborFsolve(1),vLaborFsolve(2)];
%         end
%         
%     end
% end
% toc
% 
% inputs.mLabor_1Fsolve = mLabor_1Fsolve;
% inputs.mLabor_2Fsolve = mLabor_2Fsolve;
% inputs.mConsumption_1Fsolve = mConsumption_1Fsolve;
% inputs.mConsumption_2Fsolve = mConsumption_2Fsolve;
% inputs.mCurrentUtilityFsolve = mCurrentUtilityFsolve;
% % inputs.mMarginalUtilityTodayFsolve = mMarginalUtilityTodayFsolve;
% % 
% % mLabor_1Fsolve=permute(mLabor_1Fsolve,[3,2,1]);
% % mLabor_2Fsolve=permute(mLabor_2Fsolve,[3,2,1]);
% % mConsumption_1Fsolve=permute(mConsumption_1Fsolve,[3,2,1]);
% % mConsumption_2Fsolve=permute(mConsumption_2Fsolve,[3,2,1]);
% % mCurrentUtilityFsolve=permute(mCurrentUtilityFsolve,[3,2,1]);
% 
% save('efficiencyMatricesNk250','mLabor_1Fsolve','mLabor_2Fsolve','mConsumption_1Fsolve','mConsumption_2Fsolve','mCurrentUtilityFsolve')
% % ��ʱ 2516.447092 �롣




%% Required matrices and vectors

% mValue0                 = utilitySteadyState.*ones(Nk,Na); inputs.mValue0 = mValue0;
mValue                  = zeros(Nk,Na);
mKPolicy                = zeros(Nk,Na);
mLaborPolicy_1          = zeros(Nk,Na);
mLaborPolicy_2          = zeros(Nk,Na); 
mConsumptionPolicy_1    = zeros(Nk,Na);
mConsumptionPolicy_2    = zeros(Nk,Na);

maxIter = 10000;
tolerance     = 1e-6;

iteration       = 1;
mDifference = zeros(maxIter,1);
mDifference(iteration) = 100;

options = optimset('Display', 'off');
opts1 = optimoptions('fsolve','Tolx',1e-6, 'Display','off');
% laborInitial=[labor_1_SteadyState,labor_2_SteadyState];

tic

% Finding value and policy functions numerically
while iteration <= maxIter  ...% make sure the last iteration does the maximization
        && ( (mDifference(iteration) > tolerance)  | (mDifference(iteration) <= tolerance && mod(iteration,10)~=2)) 
        
    expectedValue0 = mValue0 * mProb_a1a2StochasticGrid';% row: kPrime, column: a, i.e., expected value if today's shock is a and I choose k as tomorrow's capital stock
    
    if (mDifference(iteration) > tolerance)    

        for ia = 1:Na
            a_1 = mGrid_a1a2(ia,1);
            a_2 = mGrid_a1a2(ia,2);

            iikPrime = 1;
            
            for ik = 1:Nk
                k = vGrid_k(ik);
                
                if mod(iteration,10) == 1 % do maximization
                    valueHighSoFar = -1000.0;
                    kChoice  = vGrid_k(1);
%                     laborInitial=[labor_1_SteadyState,labor_2_SteadyState];
                    
                    for ikPrime = ikStochasticGrid(iikPrime:end)
                        kPrime = vGrid_k(ikPrime);

                        [valueProvisional,labor_1,labor_2,consumption_1,consumption_2] = valueFunction_stochasticGrid...
                            (kPrime,ikPrime,ik,k,ia,a_1,a_2,expectedValue0,bbeta,mmu_1,mmu_2,ddelta,aalphaK,aalphaL);
%                         laborInitial = [labor_1,labor_2];
%                         valueProvisional = outputValueFunction(1);
%                         consumption_1 = outputValueFunction(2);
%                         consumption_2 = outputValueFunction(3);

                        if (valueProvisional>valueHighSoFar)
                            valueHighSoFar = valueProvisional;
                            kChoice = vGrid_k(ikPrime);
                            iikPrime = sum(ikPrime >= ikStochasticGrid);
                        else
                            break
                        end
                    end
               
                    mValue(ik,ia) = valueHighSoFar;
                    mKPolicy(ik,ia) = kChoice;
                    mLaborPolicy_1(ik,ia) = labor_1;
                    mLaborPolicy_2(ik,ia) = labor_2;
                    mConsumptionPolicy_1(ik,ia) = consumption_1;
                    mConsumptionPolicy_2(ik,ia) = consumption_2;
                    
%                     if ik == 1
%                         [kPrime, vAux] = fminbnd(@(kPrime) ...
%                             -valueFunction(kPrime,ik,k,ia,a_1,a_2,expectedValue0,bbeta,mmu_1,mmu_2,ddelta,aalphaK,aalphaL),...
%                             vGrid_k(1),min(1.2*vGrid_k(ik),vGrid_k(end)),options);
% 
%                     else
%                         [kPrime, vAux] = fminbnd(@(kPrime) ...
%                             -valueFunction(kPrime,ik,k,ia,a_1,a_2,expectedValue0,bbeta,mmu_1,mmu_2,ddelta,aalphaK,aalphaL),...
%                             mKPolicy((ik-1),ia),min(1.2*vGrid_k(ik),vGrid_k(end)),options);
%                     end
% 
%                     mKPolicy(ik,ia) = kPrime;
%                     mValue(ik,ia) = -vAux;           
% 
%                     vLabor = fsolve(@(labor) laborFunction(labor,a_1,a_2,k,kPrime,mmu_1,mmu_2,aalphaK,aalphaL,ddelta), laborInitial,opts1);
%                     mLaborPolicy_1(ik,ia) = vLabor(1);
%                     mLaborPolicy_2(ik,ia) = vLabor(2);
%                     mConsumptionPolicy_1(ik,ia) = consumptionFunction1(a_1,k,kPrime,vLabor(1),aalphaK,aalphaL,ddelta);
%                     mConsumptionPolicy_2(ik,ia) = consumptionFunction2(a_2,vLabor(2));
%                     laborInitial=[vLabor(1),vLabor(2)]; % update the initial guess for labor policy to speed up the process
                else
%                     currentUtility = interp1(vGrid_k,mCurrentUtilityFsolve(:,ia,ik),mKPolicy(ik,ia));
                    currentUtility = utilityFunction(mConsumptionPolicy_1(ik,ia),mConsumptionPolicy_2(ik,ia),mLaborPolicy_1(ik,ia),mLaborPolicy_2(ik,ia),mmu_1,mmu_2);
                    expectedValue = expectedValue0(sum(mKPolicy(ik,ia)>=vGrid_k),ia);
                    value = (1-bbeta)*currentUtility + bbeta * expectedValue;
                    
                    mValue(ik,ia) = value;
                    
                end
            end
        end
        iteration = iteration + 1;
        mDifference(iteration) = max(abs(mValue - mValue0),[],'all');
        mValue0         = mValue;

%         if mod(iteration,10) == 2
        fprintf(' Iteration: %2.0f, Sup diff: %2.8f\n', iteration-1, mDifference(iteration)); 
%         end

    else

        for ia = 1:Na
            a_1 = mGrid_a1a2(ia,1);
            a_2 = mGrid_a1a2(ia,2);

            iikPrime = 1;
            
            for ik = 1:Nk
                k = vGrid_k(ik);
                
%                 if mod(iteration,10) == 1
                    valueHighSoFar = -1000.0;
                    kChoice  = vGrid_k(1);
            
                    for ikPrime = ikStochasticGrid(iikPrime:end)
                        kPrime = vGrid_k(ikPrime);
                        
                        laborInitial=[labor_1_SteadyState,labor_2_SteadyState];

                        [valueProvisional,labor_1,labor_2,consumption_1,consumption_2] = valueFunction_stochasticGrid...
                            (kPrime,ikPrime,ik,k,ia,a_1,a_2,expectedValue0,bbeta,mmu_1,mmu_2,ddelta,aalphaK,aalphaL,laborInitial);
                        laborInitial = [labor_1,labor_2];
%                         valueProvisional = outputValueFunction(1);
%                         consumption_1 = outputValueFunction(2);
%                         consumption_2 = outputValueFunction(3);

                        if (valueProvisional>valueHighSoFar)
                            valueHighSoFar = valueProvisional;
                            kChoice = vGrid_k(ikPrime);
                            iikPrime = sum(ikPrime >= ikStochasticGrid);
                        else
                            break
                        end
                    end
               
                    mValue(ik,ia) = valueHighSoFar;
                    mKPolicy(ik,ia) = kChoice;
                    mLaborPolicy_1(ik,ia) = labor_1;
                    mLaborPolicy_2(ik,ia) = labor_2;
                    mConsumptionPolicy_1(ik,ia) = consumption_1;
                    mConsumptionPolicy_2(ik,ia) = consumption_2;
                    
%                     if ik == 1
%                         [kPrime, vAux] = fminbnd(@(kPrime) ...
%                             -valueFunction(kPrime,ik,k,ia,a_1,a_2,expectedValue0,bbeta,mmu_1,mmu_2,ddelta,aalphaK,aalphaL),...
%                             vGrid_k(1),min(1.2*vGrid_k(ik),vGrid_k(end)),options);
% 
%                     else
%                         [kPrime, vAux] = fminbnd(@(kPrime) ...
%                             -valueFunction(kPrime,ik,k,ia,a_1,a_2,expectedValue0,bbeta,mmu_1,mmu_2,ddelta,aalphaK,aalphaL),...
%                             mKPolicy((ik-1),ia),min(1.2*vGrid_k(ik),vGrid_k(end)),options);
%                     end
% 
%                     mKPolicy(ik,ia) = kPrime;
%                     mValue(ik,ia) = -vAux;           
% 
%                     vLabor = fsolve(@(labor) laborFunction(labor,a_1,a_2,k,kPrime,mmu_1,mmu_2,aalphaK,aalphaL,ddelta), laborInitial,opts1);
%                     mLaborPolicy_1(ik,ia) = vLabor(1);
%                     mLaborPolicy_2(ik,ia) = vLabor(2);
%                     mConsumptionPolicy_1(ik,ia) = consumptionFunction1(a_1,k,kPrime,vLabor(1),aalphaK,aalphaL,ddelta);
%                     mConsumptionPolicy_2(ik,ia) = consumptionFunction2(a_2,vLabor(2));
%                     laborInitial=[vLabor(1),vLabor(2)]; % update the initial guess for labor policy to speed up the process
%                 else
%                     currentUtility = interp1(vGrid_k,mCurrentUtilityFsolve(:,ia,ik),mKPolicy(ik,ia));
%                     currentUtility = utilityFunction(mConsumptionPolicy_1(ik,ia),mConsumptionPolicy_2(ik,ia),mLaborPolicy_1(ik,ia),mLaborPolicy_2(ik,ia),mmu_1,mmu_2);
%                     expectedValue = expectedValue0(sum(mKPolicy(ik,ia)>=vGrid_k),ia);
%                     value = (1-bbeta)*currentUtility + bbeta * expectedValue;
%                     
%                     mValue(ik,ia) = value;
%                     
%                 end
            end
        end
        iteration = iteration + 1;
        mDifference(iteration) = max(abs(mValue - mValue0),[],'all');
        mValue0         = mValue;

%         if mod(iteration,10) == 2
        fprintf(' Iteration: %2.0f, Sup diff: %2.8f\n', iteration-1, mDifference(iteration)); 
%         end

        if mDifference(iteration) <= tolerance
            break
        end
    end
%         iteration = iteration + 1;
%         mDifference(iteration) = max(abs(mValue - mValue0),[],'all');
%         mValue0         = mValue;
% 
%         fprintf(' Iteration: %2.0f, Sup diff: %2.6f\n', iteration-1, mDifference(iteration)); 

end

toc

fprintf(' Convergence achieved. Total Number of Iteration: %2.0f, Sup diff: %2.8f\n', iteration-1, mDifference(iteration)); 



%% For accuracy test, compute the euler equation error

% Let's use LINEAR INTERPOLATION for tomorrow's values

errorEulerEquationLinearInterpolation = eulerEquationErrorFunction(Nk,vGrid_k,mKPolicy,mLaborPolicy_1,mConsumptionPolicy_1,mConsumptionPolicy_2,Na,mGrid_a1a2,mProb_a1a2,bbeta,mmu_1,mmu_2,ddelta,aalphaK,aalphaL);
errorEulerEquationLinearInterpolationDecimalLog = log10( errorEulerEquationLinearInterpolation );

[kk,aa]=meshgrid(vGrid_k, mGrid_a1a2(:,1));

figure
mesh(kk, aa, errorEulerEquationLinearInterpolationDecimalLog');

title('Euler Equation Error $log_{10}$ Linear Interpolation - Accelerator','interpreter','latex')
xlabel('Capital Stock $k$','interpreter','latex')
ylabel('shocks $z_1$ $z_2$','interpreter','latex')
zlabel('error','interpreter','latex')
xlim([min(vGrid_k),max(vGrid_k)])
ylim([min(mGrid_a1a2(:,1)),max(mGrid_a1a2(:,1))])
savefig('q3_eulerEquationErrorLinearInterpolation_accelerator')

save ShashaWang_JFV_PS1_500_stochastic_capital_grid_points_valueFunctionIteration_setLaborToSteadyState_thenDoRealValueFunctionIteration_accelerator

%  Iteration:  1, Sup diff: 0.00128356
%  Iteration: 11, Sup diff: 0.00061426
%  Iteration: 21, Sup diff: 0.00038861
%  Iteration: 31, Sup diff: 0.00025225
%  Iteration: 41, Sup diff: 0.00016538
%  Iteration: 51, Sup diff: 0.00010888
%  Iteration: 61, Sup diff: 0.00007183
%  Iteration: 71, Sup diff: 0.00004744
%  Iteration: 81, Sup diff: 0.00003137
%  Iteration: 91, Sup diff: 0.00002075
%  Iteration: 101, Sup diff: 0.00001374
%  Iteration: 111, Sup diff: 0.00000910
%  Iteration: 121, Sup diff: 0.00000603
%  Iteration: 131, Sup diff: 0.00000400
%  Iteration: 141, Sup diff: 0.00000265
%  Iteration: 151, Sup diff: 0.00000176
%  Iteration: 161, Sup diff: 0.00000117
% Elapsed time is 2100.471542 seconds.
%  Convergence achieved. Total Number of Iteration: 166, Sup diff: 0.00000095

%% figures for Value Function Iteration with a Fixed Grid

figure
mesh(kk, aa, mValue');

title('Value - Accelerator','interpreter','latex')
xlabel('Capital Stock $k$','interpreter','latex')
ylabel('shocks $z_1$ $z_2$','interpreter','latex')
zlabel('Value','interpreter','latex')
xlim([min(vGrid_k),max(vGrid_k)])
ylim([min(mGrid_a1a2(:,1)),max(mGrid_a1a2(:,1))])
savefig('q3_value_accelerator')

figure
mesh(kk, aa, mKPolicy');

title('Policy for Next Period Capital - Accelerator','interpreter','latex')
xlabel('Capital Stock $k$','interpreter','latex')
ylabel('shocks $z_1$ $z_2$','interpreter','latex')
zlabel('Next Period Capital $k\prime$','interpreter','latex')
xlim([min(vGrid_k),max(vGrid_k)])
ylim([min(mGrid_a1a2(:,1)),max(mGrid_a1a2(:,1))])
savefig('q3_kPolicy_accelerator')

figure
mesh(kk, aa, mLaborPolicy_1');

title('Policy for Good 1 Labor - Accelerator','interpreter','latex')
xlabel('Capital Stock $k$','interpreter','latex')
ylabel('shocks $z_1$ $z_2$','interpreter','latex')
zlabel('Good 1 Labor','interpreter','latex')
xlim([min(vGrid_k),max(vGrid_k)])
ylim([min(mGrid_a1a2(:,1)),max(mGrid_a1a2(:,1))])
savefig('q3_laborPolicy_1_accelerator')

figure
mesh(kk, aa, mLaborPolicy_2');

title('Policy for Good 2 Labor - Accelerator','interpreter','latex')
xlabel('Capital Stock $k$','interpreter','latex')
ylabel('shocks $z_1$ $z_2$','interpreter','latex')
zlabel('Good 2 Labor','interpreter','latex')
xlim([min(vGrid_k),max(vGrid_k)])
ylim([min(mGrid_a1a2(:,1)),max(mGrid_a1a2(:,1))])
savefig('q3_laborPolicy_2_accelerator')

figure
mesh(kk, aa, mConsumptionPolicy_1');

title('Policy for Good 1 Consumption - Accelerator','interpreter','latex')
xlabel('Capital Stock $k$','interpreter','latex')
ylabel('shocks $z_1$ $z_2$','interpreter','latex')
zlabel('Good 1 Consumption','interpreter','latex')
xlim([min(vGrid_k),max(vGrid_k)])
ylim([min(mGrid_a1a2(:,1)),max(mGrid_a1a2(:,1))])
savefig('q3_consumptionPolicy_1_accelerator')

figure
mesh(kk, aa, mConsumptionPolicy_2');

title('Policy for Good 2 Consumption- Accelerator','interpreter','latex')
xlabel('Capital Stock $k$','interpreter','latex')
ylabel('shocks $z_1$ $z_2$','interpreter','latex')
zlabel('Good 2 Consumption','interpreter','latex')
xlim([min(vGrid_k),max(vGrid_k)])
ylim([min(mGrid_a1a2(:,1)),max(mGrid_a1a2(:,1))])
savefig('q3_consumptionPolicy_2_accelerator')
