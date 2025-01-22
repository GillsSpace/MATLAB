
% Data Hyper-paramaters =============================================
start_month = 201001;
end_month = 202212;
ROLLOVER = 6;
INITIAL_BALANCE = 1000;
TC = 0.0005;
STOCKS_EACH_DAY = 30;
% ===================================================================

% Initilize Variables ===============================================
total_months = end_month - start_month;
years = floor(total_months/100);
total_months = total_months - 100*years + 12*years;
balance = INITIAL_BALANCE;
balance_compound = INITIAL_BALANCE;

% Initilize Results Arrays:
mr_result = zeros(1,total_months-ROLLOVER);
balance_result = zeros(1,total_months-ROLLOVER);
balance_compound_result = zeros(1,total_months-ROLLOVER);
traded_ff = NaN(STOCKS_EACH_DAY,31,total_months-ROLLOVER);
traded_yy = NaN(STOCKS_EACH_DAY,31,total_months-ROLLOVER);
traded_mr_result = zeros(1,total_months-ROLLOVER);
% ===================================================================

% Warning Supression:
warning("off","stats:regress:RankDefDesignMat")

% Function to increase date by months:
function date = months_add(base_date,months_added)
    years = floor(months_added/12);
    months = mod(months_added,12);
    date = base_date + 100*years + months;
    if mod(date,100) > 12
        date = date + 88;
    end
end

% Start Clock
tic;

% Main Trainging and Testing Loop ===================================
i = 1;
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
    
    % Inputs & Outputs
    rtxm_yesterday = rtxm_day(:,1:end-1);
    rtxm_yesterday_afternoon = rtxm_afternoon(:,1:end-1);
    rtxm_lastnight = rtxm_night(:,2:end);
    vol_yesterday_change = (vol_afternoon(:,1:end-1) - vol_morning(:,1:end-1)) ./ vol_morning(:,1:end-1);
    rtxm_today = rtxm_day(:,2:end);

    good = loaddata("good_now",i_start,i_end);
    good = good(:, 1:end-1) & good(:,2:end) == 1;
    good = good & ~isnan(rtxm_yesterday) & ~isnan(rtxm_yesterday_afternoon) & ~isnan(rtxm_lastnight)...
        & ~isnan(vol_yesterday_change)...
        & ~isnan(rtxm_today);

    %Predictions
    pred_a = regress(rtxm_today(good),rtxm_yesterday(good));
    pred_b = regress(rtxm_today(good),rtxm_yesterday_afternoon(good));
    pred_c = regress(rtxm_today(good),rtxm_lastnight(good));
    pred_d = regress(rtxm_today(good),vol_yesterday_change(good));

    % Testing Prediction
    t_rtxm_day = loaddata("rtxm_byti",i_test,i_test,2);
    t_rtxm_night = loaddata("rtxm_byti",i_test,i_test,1); 
    t_rtxm_morning = loaddata("rtxm_byti",i_test,i_test,3);
    t_rtxm_afternoon = loaddata("rtxm_byti",i_test,i_test,5);
    t_vol_day = loaddata("volall_day",i_test,i_test,1);
    t_vol_morning = loaddata("volcum_bytm",i_test,i_test,2); 
    t_vol_afternoon = t_vol_day - t_vol_morning;
    t_r_day = loaddata("r_byti",i_test,i_test,2);
    
    % Testing Inputs & Outputs
    t_rtxm_yesterday = t_rtxm_day(:,1:end-1);
    t_rtxm_yesterday_afternoon = t_rtxm_afternoon(:,1:end-1);
    t_rtxm_lastnight = t_rtxm_night(:,2:end);
    t_vol_yesterday_change = (t_vol_afternoon(:,1:end-1) - t_vol_morning(:,1:end-1)) ./ t_vol_morning(:,1:end-1);
    t_rtxm_today = t_rtxm_day(:,2:end);
    t_r_today = t_r_day(:,2:end);

    t_good = loaddata("good_now",i_test,i_test);
    t_good = t_good(:, 1:end-1) & t_good(:,2:end) == 1;
    t_good = t_good & ~isnan(t_rtxm_yesterday) & ~isnan(t_rtxm_yesterday_afternoon) & ~isnan(t_rtxm_lastnight)...
        & ~isnan(t_vol_yesterday_change)...
        & ~isnan(t_rtxm_today) & ~isnan(t_r_today);

    ff = (pred_a * t_rtxm_yesterday(t_good)) +...
        (pred_b * t_rtxm_yesterday_afternoon(t_good)) +...
        (pred_c * t_rtxm_lastnight(t_good)) +...
        (pred_d * t_vol_yesterday_change(t_good));

    yy = t_rtxm_today(t_good);

    result = iccalc(ff,yy);

    day_forcasts = zeros(STOCKS_EACH_DAY,size(t_good,2));
    day_actual = zeros(STOCKS_EACH_DAY,size(t_good,2));

    % Trading Algorithm ---------------------------------------------
    for j = 1:size(t_good,2)

        forcast = (pred_a * t_rtxm_yesterday(t_good(:,j),j)) +...
            (pred_b * t_rtxm_yesterday_afternoon(t_good(:,j),j)) +...
            (pred_c * t_rtxm_lastnight(t_good(:,j),j)) +...
            (pred_d * t_vol_yesterday_change(t_good(:,j),j));

        forcast = (abs(forcast) - TC) .* sign(forcast);
        forcast(abs(forcast)<TC) = 0;

        [ NA, forcast_index] = sort(forcast);

        day_returns = t_r_today(t_good(:,j),j);

        day_short = ((day_returns(forcast_index(1:STOCKS_EACH_DAY/2)) .* -1) -TC) .* INITIAL_BALANCE/STOCKS_EACH_DAY;
        day_long = ((day_returns(forcast_index(end-(STOCKS_EACH_DAY/2)+1:end))) -TC) .* INITIAL_BALANCE/STOCKS_EACH_DAY;

        day_short_compound = ((day_returns(forcast_index(1:STOCKS_EACH_DAY/2)) .* -1) +1-TC) .* balance_compound/STOCKS_EACH_DAY;
        day_long_compound = ((day_returns(forcast_index(end-(STOCKS_EACH_DAY/2)+1:end))) +1-TC) .* balance_compound/STOCKS_EACH_DAY;

        balance = balance + sum(day_long) + sum(day_short);
        balance_compound = sum(day_long_compound) + sum(day_short_compound);

        day_rtxm_actual = t_rtxm_today(t_good(:,j),j);
        yyy = cat(1,day_returns(forcast_index(1:STOCKS_EACH_DAY/2)), day_returns(forcast_index(end-(STOCKS_EACH_DAY/2)+1:end)));
        fff = cat(1,forcast(forcast_index(1:STOCKS_EACH_DAY/2)), forcast(forcast_index(end-(STOCKS_EACH_DAY/2)+1:end)));

        traded_yy(:,j,i) = yyy;
        traded_ff(:,j,i) = fff;

    end
    % ---------------------------------------------------------------

    mr_result(i) = result.mr;
    balance_result(i) = balance; 
    balance_compound_result(i) = balance_compound;

    daily_result = iccalc(traded_ff(:,1:size(t_good,2),i),traded_yy(:,1:size(t_good,2),i));
    traded_mr_result(i) = daily_result.mr;

    i = i + 1;

end
% ===================================================================

toc

%STATS: =============================================================
balance_result_base = [INITIAL_BALANCE balance_result];
monthly_earnings = balance_result_base(2:end)-balance_result_base(1:end-1);

fprintf("\nInitial Balance             : %.2f \n",INITIAL_BALANCE)
fprintf("Final Balance w/o Compunding: %.2f \n",balance)
fprintf("Final Balance w/  Compunding: %.2f \n",balance_compound)

fprintf("\nMonths Profitable: \n")
csign(monthly_earnings)

fprintf("\nAverage Monthly Return: %.3f%%\n", mean(monthly_earnings) / INITIAL_BALANCE*100)
fprintf("Average Monthly Sharpe: %.3f\n", sharpe(monthly_earnings))

fprintf("\nAverage MR of Model        : %.3f bps\n",mean(mr_result)*10000)
fprintf("Average MR of Traded Stocks: %.3f bps\n",mean(traded_mr_result)*10000)

% ===================================================================

% Good Potential Plots ==============================================
% traded_mr_result          --> plots monthly mr of the stocks actually traded each day
% mr_result                 --> plots monthly mr of the model on all stocks
% balance_result            --> balance by month w/o compounding
% balance_compound_result   --> balnce by month w/ compunding
% ===================================================================