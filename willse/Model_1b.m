% Start/End Months
start_month = 201001;
end_month = 202212;

% Data Hyper-paramaters:
ROLLOVER = 4;
INITIAL_BALANCE = 1000;
TC = 0.0005;

% Time Frane
total_months = end_month - start_month;
years = floor(total_months/100);
total_months = total_months - 100*years + 12*years;
day_balance = INITIAL_BALANCE;
morning_balance = INITIAL_BALANCE;

% Function to increase date by months:
function date = months_add(base_date,months_added)
    years = floor(months_added/12);
    months = mod(months_added,12);

    date = base_date + 100*years + months;

    if mod(date,100) > 12
        date = date + 88;
    end
end

% Initilize Results Arrays:
mr_day = zeros(1,total_months-ROLLOVER);
mr_morning = zeros(1,total_months-ROLLOVER);

i = 1;
tic;
while i <= total_months - ROLLOVER
    
    %Loop variables
    i_start = months_add(start_month,i-1);
    i_end = months_add(start_month,ROLLOVER+i-2);
    i_test = months_add(start_month,ROLLOVER+i-1);

    %Data Loadings and Cleaning
    rtxm_day = loaddata("rtxm_byti",i_start,i_end,2);
    rtxm_night = loaddata("rtxm_byti",i_start,i_end,1); 
    rtxm_morning = loaddata("rtxm_byti",i_start,i_end,3);
    rtxm_afternoon = loaddata("rtxm_byti",i_start,i_end,5);

    vol_day = loaddata("volall_day",i_start,i_end,1);
    vol_morning = loaddata("volcum_bytm",i_start,i_end,2); 
    vol_afternoon = vol_day - vol_morning;
    
    % Inputs
    rtxm_yesterday = rtxm_day(:,1:end-1);
    rtxm_yesterday_afternoon = rtxm_afternoon(:,1:end-1);
    rtxm_lastnight = rtxm_night(:,2:end);
    vol_yesterday_change = (vol_afternoon(:,1:end-1) - vol_morning(:,1:end-1)) ./ vol_morning(:,1:end-1);

    %Outputs
    rtxm_today = rtxm_day(:,2:end);
    rtxm_today_morning = rtxm_morning(:,2:end);

    good = loaddata("good_now",i_start,i_end);
    good = good(:, 1:end-1) & good(:,2:end) == 1;
    good = good & ~isnan(rtxm_yesterday) & ~isnan(rtxm_yesterday_afternoon) & ~isnan(rtxm_lastnight)...
        & ~isnan(vol_yesterday_change)...
        & ~isnan(rtxm_today) & ~isnan(rtxm_today_morning);

    %Predictions
    day_pred_a = regress(rtxm_today(good),rtxm_yesterday(good));
    day_pred_b = regress(rtxm_today(good),rtxm_yesterday_afternoon(good));
    day_pred_c = regress(rtxm_today(good),rtxm_lastnight(good));
    day_pred_d = regress(rtxm_today(good),vol_yesterday_change(good));

    morning_pred_a = regress(rtxm_today_morning(good),rtxm_yesterday(good));
    morning_pred_b = regress(rtxm_today_morning(good),rtxm_yesterday_afternoon(good));
    morning_pred_c = regress(rtxm_today_morning(good),rtxm_lastnight(good));
    morning_pred_d = regress(rtxm_today_morning(good),vol_yesterday_change(good));

    % Testing Prediction
    t_rtxm_day = loaddata("rtxm_byti",i_test,i_test,2);
    t_rtxm_night = loaddata("rtxm_byti",i_test,i_test,1); 
    t_rtxm_morning = loaddata("rtxm_byti",i_test,i_test,3);
    t_rtxm_afternoon = loaddata("rtxm_byti",i_test,i_test,5);

    t_vol_day = loaddata("volall_day",i_test,i_test,1);
    t_vol_morning = loaddata("volcum_bytm",i_test,i_test,2); 
    t_vol_afternoon = t_vol_day - t_vol_morning;
    
    % Inputs
    t_rtxm_yesterday = t_rtxm_day(:,1:end-1);
    t_rtxm_yesterday_afternoon = t_rtxm_afternoon(:,1:end-1);
    t_rtxm_lastnight = t_rtxm_night(:,2:end);
    t_vol_yesterday_change = (t_vol_afternoon(:,1:end-1) - t_vol_morning(:,1:end-1)) ./ t_vol_morning(:,1:end-1);

    %Outputs
    t_rtxm_today = t_rtxm_day(:,2:end);
    t_rtxm_today_morning = t_rtxm_morning(:,2:end);

    t_good = loaddata("good_now",i_test,i_test);
    t_good = t_good(:, 1:end-1) & t_good(:,2:end) == 1;
    t_good = t_good & ~isnan(t_rtxm_yesterday) & ~isnan(t_rtxm_yesterday_afternoon) & ~isnan(t_rtxm_lastnight)...
        & ~isnan(t_vol_yesterday_change)...
        & ~isnan(t_rtxm_today) & ~isnan(t_rtxm_today_morning);

    day_ff = (day_pred_a * t_rtxm_yesterday(t_good)) +...
        (day_pred_b * t_rtxm_yesterday_afternoon(t_good)) +...
        (day_pred_c * t_rtxm_lastnight(t_good)) +...
        (day_pred_d * t_vol_yesterday_change(t_good));

    morning_ff = (morning_pred_a * t_rtxm_yesterday(t_good)) +...
        (morning_pred_b * t_rtxm_yesterday_afternoon(t_good)) +...
        (morning_pred_c * t_rtxm_lastnight(t_good)) +...
        (morning_pred_d * t_vol_yesterday_change(t_good));

    day_yy = t_rtxm_today(t_good);
    morning_yy = t_rtxm_today_morning(t_good);

    day_result = iccalc(day_ff,day_yy);
    morning_result = iccalc(morning_ff,morning_yy);

    mr_day(i) = day_result.mr;
    mr_morning(i) = morning_result.mr;

    %day_balance = day_balance * (1+(day_result.mr*100/size(t_rtxm_day,2)))^size(t_rtxm_day,2);
    %morning_balance = morning_balance * (1+(morning_result.mr*100/size(t_rtxm_day,2)))^size(t_rtxm_day,2);

    %Loop progression
    i = i + 1;

end
toc

f1 = figure;
plot(1:total_months-ROLLOVER,mr_day,'-r',...
    1:total_months-ROLLOVER,mr_morning,'-b')

% sharp_day = mean(mr_day) / std(mr_day)
% sharp_morning = mean(mr_morning) / std(mr_morning)
