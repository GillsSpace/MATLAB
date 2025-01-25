
% Data Hyper-parameters =============================================
START_MONTH = 201001;
END_MONTH = 202212;
ROLLOVER = 2;
INITIAL_BALANCE = 10000;    % $10,000
TC = 0.00055;               % 5.5 Bps Fee (Excluding HalfMidCost)
STOCKS_EACH_DAY = 30;
RETENTION = 0.88;
% ===================================================================

% Initialize Variables ===============================================
total_months = calculate_total_months(START_MONTH,END_MONTH);
balance = INITIAL_BALANCE;
balance_noFees = INITIAL_BALANCE;

monthly_mr =                zeros(1,total_months-ROLLOVER);
monthly_balance =           zeros(1,total_months-ROLLOVER);
monthly_balance_noFees =    zeros(1,total_months-ROLLOVER);
traded_mr_result =          zeros(1,total_months-ROLLOVER);

traded_ff = NaN(STOCKS_EACH_DAY,31,total_months-ROLLOVER);
traded_yy = NaN(STOCKS_EACH_DAY,31,total_months-ROLLOVER);

coef_d = 0;
coef_e = 0;
coef_f = 0;
coef_g = 0;
coef_h = 0;
coef_i = 0;
% ===================================================================

% Warning Suppression:
warning("off","stats:regress:RankDefDesignMat")

% Start Clock
tic;

% Main Training and Testing Loop ===================================
i = 1;
while i <= total_months - ROLLOVER
    
    %Loop variables
    start_month = increment_month(START_MONTH,i-1);
    end_month = increment_month(START_MONTH,ROLLOVER+i-2);
    test_month = increment_month(START_MONTH,ROLLOVER+i-1);

    %Data Loadings and Cleaning
    rtxm_day = loaddata("rtxm_byti",start_month,end_month,2);
    rr_day = loaddata("rrirpnxm_byti",start_month,end_month,2);
    rr_afternoon = loaddata("rrirpnxm_byti",start_month,end_month,5);
    rr_night = loaddata("rrirpnxm_byti",start_month,end_month,1);
    cf_day = loaddata("cfirpnxm_byti",start_month,end_month,2);
    cf_afternoon = loaddata("cfirpnxm_byti",start_month,end_month,5);
    cf_night = loaddata("cfirpnxm_byti",start_month,end_month,1);
    
    % Inputs & Outputs
    rr_yesterday = rr_day(:,1:end-1);
    rr_yesterday_afternoon = rr_afternoon(:,1:end-1);
    rr_lastnight = rr_night(:,2:end);
    cf_yesterday = cf_day(:,1:end-1);
    cf_yesterday_afternoon = cf_afternoon(:,1:end-1);
    cf_lastnight = cf_night(:,2:end);
    rtxm_today = rtxm_day(:,2:end);

    good = loaddata("good_now",start_month,end_month);
    good = good(:, 1:end-1) & good(:,2:end) == 1;
    good = good...
        & ~isnan(rr_yesterday)...
        & ~isnan(rr_yesterday_afternoon)...
        & ~isnan(rr_lastnight)...
        & ~isnan(cf_yesterday)...
        & ~isnan(cf_yesterday_afternoon)...
        & ~isnan(cf_lastnight)...
        & ~isnan(rtxm_today);

    % Calculating Coefficients: -------------------------------------------
    local_coef_d = regress(rtxm_today(good),rr_yesterday(good));
    local_coef_e = regress(rtxm_today(good),rr_yesterday_afternoon(good));
    local_coef_f = regress(rtxm_today(good),rr_lastnight(good));
    local_coef_g = regress(rtxm_today(good),cf_yesterday(good));
    local_coef_h = regress(rtxm_today(good),cf_yesterday_afternoon(good));
    local_coef_i = regress(rtxm_today(good),cf_lastnight(good));

    coef_d = coef_d * RETENTION + local_coef_d * (1-RETENTION);
    coef_e = coef_e * RETENTION + local_coef_e * (1-RETENTION);
    coef_f = coef_f * RETENTION + local_coef_f * (1-RETENTION);
    coef_g = coef_g * RETENTION + local_coef_g * (1-RETENTION);
    coef_h = coef_h * RETENTION + local_coef_h * (1-RETENTION);
    coef_i = coef_i * RETENTION + local_coef_i * (1-RETENTION);
    
    if i == 1
        coef_d = local_coef_d;
        coef_e = local_coef_e;
        coef_f = local_coef_f;
        coef_g = local_coef_g;
        coef_h = local_coef_h;
        coef_i = local_coef_i;
    end

    % --------------------------------------------------------------------

    % Testing Prediction
    t_rtxm_day = loaddata("rtxm_byti",test_month,test_month,2);
    t_rr_day = loaddata("rrirpnxm_byti",test_month,test_month,2);
    t_rr_afternoon = loaddata("rrirpnxm_byti",test_month,test_month,5);
    t_rr_night = loaddata("rrirpnxm_byti",test_month,test_month,1);
    t_cf_day = loaddata("cfirpnxm_byti",test_month,test_month,2);
    t_cf_afternoon = loaddata("cfirpnxm_byti",test_month,test_month,5);
    t_cf_night = loaddata("cfirpnxm_byti",test_month,test_month,1);
    t_r_day = loaddata("r_byti",test_month,test_month,2);
    
    % Testing Inputs & Outputs
    t_rr_yesterday = t_rr_day(:,1:end-1);
    t_rr_yesterday_afternoon = t_rr_afternoon(:,1:end-1);
    t_rr_lastnight = t_rr_night(:,2:end);
    t_cf_yesterday = t_cf_day(:,1:end-1);
    t_cf_yesterday_afternoon = t_cf_afternoon(:,1:end-1);
    t_cf_lastnight = t_cf_night(:,2:end);
    t_rtxm_today = t_rtxm_day(:,2:end);
    t_r_today = t_r_day(:,2:end);

    t_good = loaddata("good_now",test_month,test_month);
    t_tc_local_open = loaddata("hlfspread_bytm",test_month,test_month,1);
    t_tc_local_close = loaddata("hlfspread_bytm",test_month,test_month,4);
    t_mid_open = loaddata("mid_open",test_month,test_month);
    t_mid_close = loaddata("mid_close",test_month,test_month);
    t_good = t_good(:, 1:end-1) & t_good(:,2:end) == 1;
    t_tc_local_open = t_tc_local_open(:,2:end);
    t_tc_local_close = t_tc_local_close(:,2:end);
    t_mid_open = t_mid_open(:,2:end);
    t_mid_close = t_mid_close(:,2:end);
    t_good = t_good...
        & ~isnan(t_rr_yesterday)...
        & ~isnan(t_rr_yesterday_afternoon)...
        & ~isnan(t_rr_lastnight)...
        & ~isnan(t_cf_yesterday)...
        & ~isnan(t_cf_yesterday_afternoon)...
        & ~isnan(t_cf_lastnight)...
        & ~isnan(t_rtxm_today) & ~isnan(t_r_today) & ~isnan(t_tc_local_open) & ~isnan(t_tc_local_close) & ~isnan(t_mid_open) & ~isnan(t_mid_close);

    ff = (coef_d * t_rr_yesterday(t_good)) +...
        (coef_e * t_rr_yesterday_afternoon(t_good)) +...
        (coef_f * t_rr_lastnight(t_good)) +...
        (coef_g * t_cf_yesterday(t_good)) +...
        (coef_h * t_cf_yesterday_afternoon(t_good)) +...
        (coef_i * t_cf_lastnight(t_good));

    yy = t_rtxm_today(t_good);

    result = iccalc(ff,yy);

    % Trading Algorithm ---------------------------------------------
    for j = 1:size(t_good,2)

        forecast = (coef_d * t_rr_yesterday(t_good(:,j),j)) +...
            (coef_e * t_rr_yesterday_afternoon(t_good(:,j),j)) +...
            (coef_f * t_rr_lastnight(t_good(:,j),j)) +...
            (coef_g * t_cf_yesterday(t_good(:,j),j)) +...
            (coef_h * t_cf_yesterday_afternoon(t_good(:,j),j)) +...
            (coef_i * t_cf_lastnight(t_good(:,j),j));

        forecast = (abs(forecast) - TC) .* sign(forecast);
        forecast(abs(forecast)<TC) = 0;

        [ NA, forecast_index] = sort(forecast);

        % Trading Costs and Return Variables
        day_returns = t_r_today(t_good(:,j),j);
        tc_open = t_tc_local_open(t_good(:,j),j);
        tc_close = t_tc_local_close(t_good(:,j),j);
        mid_open = t_mid_open(t_good(:,j),j);
        mid_close = t_mid_close(t_good(:,j),j);
        idx_short = forecast_index(1:STOCKS_EACH_DAY/2);
        idx_long = forecast_index(end-(STOCKS_EACH_DAY/2)+1:end);
        balance_per_stock = INITIAL_BALANCE/STOCKS_EACH_DAY;

        % Balance Calculations
        day_short_costs =   mid_close(idx_short)    + tc_close(idx_short);
        day_long_costs =    mid_open(idx_long)      + tc_open(idx_long);
        day_short_returns = mid_open(idx_short)     - tc_open(idx_short);
        day_long_returns =  mid_close(idx_long)     - tc_close(idx_long);
        day_short_positions = floor(balance_per_stock ./ day_short_costs);
        day_long_positions = floor(balance_per_stock ./ day_long_costs);
        day_short = sum((day_short_returns - day_short_costs) .* day_short_positions .* (1-TC));
        day_long = sum((day_long_returns - day_long_costs) .* day_long_positions .* (1-TC));
        balance = balance + sum(day_long) + sum(day_short);

        % Balance Calculations w/o Fees
        day_short_costs =   mid_close(idx_short);
        day_long_costs =    mid_open(idx_long);
        day_short_returns = mid_open(idx_short);
        day_long_returns =  mid_close(idx_long);
        day_short_positions = floor(balance_per_stock ./ day_short_costs);
        day_long_positions = floor(balance_per_stock ./ day_long_costs);
        day_short = sum((day_short_returns - day_short_costs) .* day_short_positions);
        day_long = sum((day_long_returns - day_long_costs) .* day_long_positions);
        balance_noFees = balance_noFees + sum(day_long) + sum(day_short);


        day_rtxm_actual = t_rtxm_today(t_good(:,j),j);
        yyy = cat(1,day_returns(idx_short), day_returns(idx_long));
        fff = cat(1,forecast(idx_short), forecast(idx_long));

        traded_yy(:,j,i) = yyy;
        traded_ff(:,j,i) = fff;

    end
    % ---------------------------------------------------------------

    monthly_mr(i) = result.mr;
    monthly_balance(i) = balance; 
    monthly_balance_noFees(i) = balance_noFees;

    daily_result = iccalc(traded_ff(:,1:size(t_good,2),i),traded_yy(:,1:size(t_good,2),i));
    traded_mr_result(i) = daily_result.mr;

    i = i + 1;

end
% ===================================================================

toc

%STATS: =============================================================
balance_result_base = [INITIAL_BALANCE monthly_balance];
monthly_earnings = balance_result_base(2:end)-balance_result_base(1:end-1);
balance_result_base_noFees = [INITIAL_BALANCE monthly_balance_noFees];
monthly_earnings_noFees = balance_result_base_noFees(2:end)-balance_result_base_noFees(1:end-1);

fprintf("\nInitial Balance             : %.2f \n",INITIAL_BALANCE)
fprintf("Final Balance w/ Fees       : %.2f \n",balance)
fprintf("Final Balance w/o Fees      : %.2f \n",balance_noFees)

fprintf("\nMonths Profitable: \n")
csign(monthly_earnings)

fprintf("\nAverage Monthly Return: %.3f%%\n", mean(monthly_earnings) / INITIAL_BALANCE*100)
fprintf("Average Monthly Sharpe: %.3f\n", sharpe(monthly_earnings))

fprintf("\nAverage Monthly Return w/o Fees: %.3f%%\n", mean(monthly_earnings_noFees) / INITIAL_BALANCE*100)
fprintf("Average Monthly Sharpe w/o Fees: %.3f\n", sharpe(monthly_earnings_noFees))

fprintf("\nAverage MR of Model        : %.3f bps\n",mean(monthly_mr)*10000)
fprintf("Average MR of Traded Stocks: %.3f bps\n",mean(traded_mr_result)*10000)
fprintf("-----------------------------------------------------\n")

% ===================================================================

% Good Potential Plots ==============================================
% traded_mr_result          --> plots monthly mr of the stocks actually traded each day
% mr_result                 --> plots monthly mr of the model on all stocks
% balance_result            --> balance by month w/o compounding
% balance_compound_result   --> balance by month w/ compounding
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