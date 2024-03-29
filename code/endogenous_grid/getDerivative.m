function mValueTildeDerivative = getDerivative(mValueTilde,NkPrime,Na,vGrid_kPrime)
% Take the derivative of ValueFunctionTilde
% Use average of the slopes of the linearly interpolated value function
    for ia = 1:Na       
        for ikPrime = 1:NkPrime
            
            if ikPrime == 1
                mValueTildeDerivative(ikPrime,ia) = (mValueTilde(ikPrime+1,ia)-...
                    mValueTilde(ikPrime,ia))/...
                    (vGrid_kPrime(ikPrime+1)-vGrid_kPrime(ikPrime));
            elseif ikPrime == NkPrime
                mValueTildeDerivative(ikPrime,ia) = (mValueTilde(ikPrime,ia)-...
                    mValueTilde(ikPrime-1,ia))/...
                    (vGrid_kPrime(ikPrime)-vGrid_kPrime(ikPrime-1));
            else
                mValueTildeDerivative(ikPrime,ia) = ((mValueTilde(ikPrime,ia)...
                        -mValueTilde(ikPrime-1,ia))/...
                       (vGrid_kPrime(ikPrime)-vGrid_kPrime(ikPrime-1))+...
                       (mValueTilde(ikPrime+1,ia)-...
                       mValueTilde(ikPrime,ia))/...
                       (vGrid_kPrime(ikPrime+1)-vGrid_kPrime(ikPrime)))/2;
            end
            
            if mValueTildeDerivative(ikPrime,ia) ==0
                mValueTildeDerivative(ikPrime,ia) =NaN;
            end
            
        end
    end
    
end