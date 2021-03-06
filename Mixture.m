classdef Mixture
    
    properties
        GASSES      %gasses in mixture
        NUM_GASSES  %number of gasses in the mixture
        Y           %mixture mol fractions
        X           %mixture mass fractions
        R           %mixture gas constant
        P0REF       %mixture P0 reference
    end
    
    methods
        function f = Mixture(g, y, p0ref)
            f.NUM_GASSES = length(g);    %set NUM_GASSES
            f.GASSES = g;                %set GASSES
            f.Y = y;                     %set Y
            inverse_sum = 0;             %temp variable to calculate X
            for i = 1:length(g)          %loop through all gasses
               inverse_sum = inverse_sum + y(i) / g(i).R;  %summing yi / Ri for constituent gasses
               f.X(i) = y(i) / g(i).R;                     %temporary, multiply by Rmix when finished calculating
            end
            f.R = 1 / inverse_sum;       %final constant calc
            f.X = f.X .* f.R;            %xi = Rmix * yi / Ri
            f.P0REF = p0ref;             %set P0REF
        end
        function sref = subsref(obj, s)  %overloaded subsref for easy data access
            switch s(1).type
                case '()'
                    if length(s) < 2
                        sref = builtin('subsref', obj.GASSES, s);
                        return

                    else
                        sref = builtin('subsref', obj, s);
                    end
                case '.'
                    sref = builtin('subsref', obj, s);
                case '{}'
                    error('Mixture:subsref',...
                        'Not a supported subscript reference')
            end
        end
    end
    
%     enumeration
%         Dry_Air ([Gas.Nitrogen, Gas.Oxygen, Gas.Argon, Gas.Carbon_Dioxide], [0.78084, 0.20947, 0.00934 0.00035], 307.6) %given mixture and mol fractions
%                                                                                                                         %P0REF from Air tables at 1273.15 K
%     end
end

