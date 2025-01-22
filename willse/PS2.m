years = 2018:2021;

right = 0;
wrong = 0;

for i = 1:numel(years)
    start_month = years(i)*100 + 1;
    end_month = years(i)*100 + 12;

    data = loaddata("rtxm_byti", start_month, end_month, 2);
    x = data(:,1:end-1);
    y = data(:,2:end);

    good = loaddata("good_now",start_month,end_month);
    good = good(:,1:end-1) & good(:,2:end) == 1;
    good = (good == 1) & ~isnan(y) & ~isnan(x);

    coef = regress(y(good),x(good))

    data = loaddata("rtxm_byti", start_month+100, end_month+100, 2);

    xx = data(:,1:end-1);
    yy = data(:,2:end);

    good2 = loaddata("good_now",start_month+100,end_month+100);
    good2 = good2(:,1:end-1) & good2(:,2:end) == 1;
    good2 = (good2 == 1) & ~isnan(yy) & ~isnan(xx);

    ff = coef * xx(good2);
    model = iccalc(ff,yy(good2));

    model.mr
    model.ic
    model.sf

    ff_pos = (ff > 0);
    yy_pos = (yy(good2) > 0);
    correct = ff_pos == yy_pos;
    right = right + sum(correct);
    wrong = wrong + numel(yy_pos) - sum(correct);
 
end





% years = 2018:2021;
% coefs = zeros(1,numel(years));
% 
% for i = 1:numel(years)
%     start_month = years(i)*100 + 1;
%     end_month = years(i)*100 + 12;
% 
%     x = loaddata("rtxm_byti", start_month, end_month, 1);
%     y = loaddata("rtxm_byti", start_month, end_month, 2);
% 
%     good = loaddata("good_now",start_month,end_month);
%     good = (good == 1) & ~isnan(y) & ~isnan(x);
% 
%     coefs(i) = regress(y(good),x(good));
% end
% 
% for i = 1:numel(coefs)
%     start_month = years(i)*100 + 101;
%     end_month = years(i)*100 + 112;
% 
%     yy = loaddata("rtxm_byti", start_month, end_month, 2);
%     xx = loaddata("rtxm_byti", start_month, end_month, 1);
% 
%     good2 = loaddata("good_now",start_month,end_month);
%     good2 = (good2 == 1) & ~isnan(yy) & ~isnan(xx);
% 
%     ff = coefs(i) * xx(good2);
% 
%     iccalc(ff,yy(good2))
% end