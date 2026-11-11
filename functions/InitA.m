function A = InitA(X, lab, anc, k, m)
num_view = length(X);
ds = 0; A = cell(1,num_view);
for iv = 1:num_view
     d{iv} = size(X{iv},1);
     if m == 1
          A{iv} = anc(:, ds+1:ds+d{iv})';
     else
         for ic = 1:k
%                 pos = find(lab == ic);
%                 if length(pos) < m
%                       pos = repmat(pos, ceil(m/length(pos)), 1);
%                 end
%                 A{iv} = [A{iv} [anc(ic, ds+1:ds+d{iv})' X{iv}(:, pos(1:m-1))] ];  

                A{iv} = [A{iv} repmat(anc(ic, ds+1:ds+d{iv})', 1, m)];
         end
     end
     ds = ds+d{iv};
end

end