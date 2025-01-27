
% Data Hyper-paramaters =============================================
START_MONTH = 201001;
END_MONTH = 202212;
ROLLOVER = 2;
INITIAL_BALANCE = 10000;    % $10,000
TC = 0.00055;               % 5.5 Bps Fee (Excluding HalfMidCost)
STOCKS_EACH_DAY = 30;
% ===================================================================

% Initilize Variables ===============================================
total_months = calculate_total_months(START_MONTH,END_MONTH);
balance = INITIAL_BALANCE;

monthly_mr =        zeros(1,total_months-ROLLOVER);
monthly_balnace =   zeros(1,total_months-ROLLOVER);
traded_mr_result = zeros(1,total_months-ROLLOVER);
traded_ff = NaN(STOCKS_EACH_DAY,31,total_months-ROLLOVER);
traded_yy = NaN(STOCKS_EACH_DAY,31,total_months-ROLLOVER);

monthly_coef_a = zeros(1,total_months-ROLLOVER);
monthly_coef_b = zeros(1,total_months-ROLLOVER);
monthly_coef_c = zeros(1,total_months-ROLLOVER);

t_coef_a = 0;
t_coef_b = 0;
t_coef_c = 0;
% ===================================================================

% Warning Supression:
warning("off","stats:regress:RankDefDesignMat")

% Start Clock
tic;

% Main Trainging and Testing Loop ===================================
i = 1;
while i <= total_months - ROLLOVER
    
    %Loop variables
    start_month = increment_month(START_MONTH,i-1);
    end_month = increment_month(START_MONTH,ROLLOVER+i-2);
    test_month = increment_month(START_MONTH,ROLLOVER+i-1);

    %Data Loadings and Cleaning
    rtxm_day = loaddata("rtxm_byti",start_month,end_month,2);
    rtxm_night = loaddata("rtxm_byti",start_month,end_month,1); 
    rtxm_morning = loaddata("rtxm_byti",start_month,end_month,3);
    rtxm_afternoon = loaddata("rtxm_byti",start_month,end_month,5);
    vol_day = loaddata("volall_day",start_month,end_month,1);
    vol_morning = loaddata("volcum_bytm",start_month,end_month,2); 
    vol_afternoon = vol_day - vol_morning;
    
    % Inputs & Outputs
    rtxm_yesterday = rtxm_day(:,1:end-1);
    rtxm_yesterday_afternoon = rtxm_afternoon(:,1:end-1);
    rtxm_lastnight = rtxm_night(:,2:end);
    vol_yesterday_change = (vol_afternoon(:,1:end-1) - vol_morning(:,1:end-1)) ./ vol_morning(:,1:end-1);
    rtxm_today = rtxm_day(:,2:end);

    good = loaddata("good_now",start_month,end_month);
    good = good(:, 1:end-1) & good(:,2:end) == 1;
    good = good & ~isnan(rtxm_yesterday) & ~isnan(rtxm_yesterday_afternoon) & ~isnan(rtxm_lastnight)...
        & ~isnan(vol_yesterday_change)...
        & ~isnan(rtxm_today);

    %Predictions
    coef_a = regress(rtxm_today(good),rtxm_yesterday(good));
    coef_b = regress(rtxm_today(good),rtxm_yesterday_afternoon(good));
    coef_c = regress(rtxm_today(good),rtxm_lastnight(good));
    %coef_d = regress(rtxm_today(good),vol_yesterday_change(good));

    t_coef_a = t_coef_a * 0.88 + coef_a * 0.12;
    t_coef_b = t_coef_b * 0.88 + coef_b * 0.12;
    t_coef_c = t_coef_c * 0.88 + coef_c * 0.12;

    % Testing Prediction
    t_rtxm_day = loaddata("rtxm_byti",test_month,test_month,2);
    t_rtxm_night = loaddata("rtxm_byti",test_month,test_month,1); 
    t_rtxm_morning = loaddata("rtxm_byti",test_month,test_month,3);
    t_rtxm_afternoon = loaddata("rtxm_byti",test_month,test_month,5);
    t_vol_day = loaddata("volall_day",test_month,test_month,1);
    t_vol_morning = loaddata("volcum_bytm",test_month,test_month,2); 
    t_vol_afternoon = t_vol_day - t_vol_morning;
    t_r_day = loaddata("r_byti",test_month,test_month,2);
    
    % Testing Inputs & Outputs
    t_rtxm_yesterday = t_rtxm_day(:,1:end-1);
    t_rtxm_yesterday_afternoon = t_rtxm_afternoon(:,1:end-1);
    t_rtxm_lastnight = t_rtxm_night(:,2:end);
    t_vol_yesterday_change = (t_vol_afternoon(:,1:end-1) - t_vol_morning(:,1:end-1)) ./ t_vol_morning(:,1:end-1);
    t_rtxm_today = t_rtxm_day(:,2:end);
    t_r_today = t_r_day(:,2:end);

    t_good = loaddata("good_now",test_month,test_month);
    t_good = t_good(:, 1:end-1) & t_good(:,2:end) == 1;
    t_good = t_good & ~isnan(t_rtxm_yesterday) & ~isnan(t_rtxm_yesterday_afternoon) & ~isnan(t_rtxm_lastnight)...
        & ~isnan(t_vol_yesterday_change)...
        & ~isnan(t_rtxm_today) & ~isnan(t_r_today);

    ff = (t_coef_a * t_rtxm_yesterday(t_good)) +...
        (t_coef_b * t_rtxm_yesterday_afternoon(t_good)) +...
        (t_coef_c * t_rtxm_lastnight(t_good));

    yy = t_rtxm_today(t_good);

    result = iccalc(ff,yy);

    day_forcasts = zeros(STOCKS_EACH_DAY,size(t_good,2));
    day_actual = zeros(STOCKS_EACH_DAY,size(t_good,2));

    % Trading Algorithm ---------------------------------------------
    for j = 1:size(t_good,2)

        forcast = (t_coef_a * t_rtxm_yesterday(t_good(:,j),j)) +...
            (t_coef_b * t_rtxm_yesterday_afternoon(t_good(:,j),j)) +...
            (t_coef_c * t_rtxm_lastnight(t_good(:,j),j));

        forcast = (abs(forcast) - TC) .* sign(forcast);
        forcast(abs(forcast)<TC) = 0;

        [ NA, forcast_index] = sort(forcast);

        day_returns = t_r_today(t_good(:,j),j);

        day_short = ((day_returns(forcast_index(1:STOCKS_EACH_DAY/2)) .* -1) -TC) .* INITIAL_BALANCE/STOCKS_EACH_DAY;
        day_long = ((day_returns(forcast_index(end-(STOCKS_EACH_DAY/2)+1:end))) -TC) .* INITIAL_BALANCE/STOCKS_EACH_DAY;

        balance = balance + sum(day_long) + sum(day_short);

        day_rtxm_actual = t_rtxm_today(t_good(:,j),j);
        yyy = cat(1,day_returns(forcast_index(1:STOCKS_EACH_DAY/2)), day_returns(forcast_index(end-(STOCKS_EACH_DAY/2)+1:end)));
        fff = cat(1,forcast(forcast_index(1:STOCKS_EACH_DAY/2)), forcast(forcast_index(end-(STOCKS_EACH_DAY/2)+1:end)));

        traded_yy(:,j,i) = yyy;
        traded_ff(:,j,i) = fff;

    end
    % ---------------------------------------------------------------

    monthly_mr(i) = result.mr;
    monthly_balnace(i) = balance; 

    monthly_coef_a(i) = t_coef_a;
    monthly_coef_b(i) = t_coef_b;
    monthly_coef_c(i) = t_coef_c;

    daily_result = iccalc(traded_ff(:,1:size(t_good,2),i),traded_yy(:,1:size(t_good,2),i));
    traded_mr_result(i) = daily_result.mr;

    i = i + 1;

end
% ===================================================================

toc

%STATS: =============================================================
balance_result_base = [INITIAL_BALANCE monthly_balnace];
monthly_earnings = balance_result_base(2:end)-balance_result_base(1:end-1);

fprintf("\nInitial Balance             : %.2f \n",INITIAL_BALANCE)
fprintf("Final Balance w/o Compunding: %.2f \n",balance)

fprintf("\nMonths Profitable: \n")
csign(monthly_earnings)

fprintf("\nAverage Monthly Return: %.3f%%\n", mean(monthly_earnings) / INITIAL_BALANCE*100)
fprintf("Average Monthly Sharpe: %.3f\n", sharpe(monthly_earnings))

fprintf("\nAverage MR of Model        : %.3f bps\n",mean(monthly_mr)*10000)
fprintf("Average MR of Traded Stocks: %.3f bps\n",mean(traded_mr_result)*10000)

% ===================================================================

% Good Potential Plots ==============================================
% traded_mr_result          --> plots monthly mr of the stocks actually traded each day
% mr_result                 --> plots monthly mr of the model on all stocks
% balance_result            --> balance by month w/o compounding
% balance_compound_result   --> balnce by month w/ compunding
% ===================================================================

% Functions =========================================================

function total_months = calculate_total_months(start_month, end_month)
    years = floor((end_month - start_month) / 100);
    months = mod(end_month - start_month, 100);
    total_months = years * 12 + months;
end

function new_date = increment_month(base_date, months_to_add)
    years = floor(months_to_add / 12);
    months = mod(months_to_add, 12);
    new_date = base_date + years * 100 + months;
    if mod(new_date, 100) > 12
        new_date = new_date + 88;
    end
end

% ===================================================================