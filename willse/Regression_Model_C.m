% Data Hyper-parameters =============================================
START_MONTH = 201001;
END_MONTH = 202212;
ROLLOVER = 2;
INITIAL_BALANCE = 10000;    % $10,000
TC = 0.00055;               % 5.5 Bps Fee (Excluding HalfMidCost)
STOCKS_EACH_DAY = 14;
RETENTION = 0.88;

VOL_UP_THRESHOLD = 0.6; %100 Increase
VOL_DOWN_THRESHOLD = -0.4; %40 Decrease
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

stock_trade_count = zeros(1,5146);

coef_d = [0,0,0];
coef_e = [0,0,0];
coef_f = [0,0,0];
coef_g = [0,0,0];
coef_h = [0,0,0];
coef_i = [0,0,0];
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
    [rr_yesterday, rr_yesterday_afternoon, rr_lastnight, cf_yesterday, cf_yesterday_afternoon, cf_lastnight, vol_yesterday_change, rtxm_today, NA]...
        = return_data(start_month, end_month, false);

    % Define the conditions as a cell array
    [d_rr_yesterday, d_rr_yesterday_afternoon, d_rr_lastnight, d_cf_yesterday, d_cf_yesterday_afternoon, d_cf_lastnight]...
        = divide_data_on_threshold(rr_yesterday, rr_yesterday_afternoon, rr_lastnight, cf_yesterday, cf_yesterday_afternoon, cf_lastnight,vol_yesterday_change,VOL_UP_THRESHOLD,VOL_DOWN_THRESHOLD);

    good = loaddata("good_now",start_month,end_month);
    good = good(:, 1:end-1) & good(:,2:end) == 1;
    good = good...
        & ~isnan(rr_yesterday)...
        & ~isnan(rr_yesterday_afternoon)...
        & ~isnan(rr_lastnight)...
        & ~isnan(cf_yesterday)...
        & ~isnan(cf_yesterday_afternoon)...
        & ~isnan(cf_lastnight)...
        & ~isnan(vol_yesterday_change)...
        & ~isnan(rtxm_today);

    % Calculating Coefficients: -------------------------------------------
    for k = 1:3
        dd_rr_yesterday = d_rr_yesterday(:, :, k);
        dd_rr_yesterday_afternoon = d_rr_yesterday_afternoon(:, :, k);
        dd_rr_lastnight = d_rr_lastnight(:, :, k);
        dd_cf_yesterday = d_cf_yesterday(:, :, k);
        dd_cf_yesterday_afternoon = d_cf_yesterday_afternoon(:, :, k);
        dd_cf_lastnight = d_cf_lastnight(:, :, k);

        local_coef_d = regress(rtxm_today(good & dd_rr_yesterday~=0),dd_rr_yesterday(good & dd_rr_yesterday~=0)); % Regress just non-zero values on current volume layer
        local_coef_e = regress(rtxm_today(good & dd_rr_yesterday_afternoon~=0),dd_rr_yesterday_afternoon(good & dd_rr_yesterday_afternoon~=0));
        local_coef_f = regress(rtxm_today(good & dd_rr_lastnight~=0),dd_rr_lastnight(good & dd_rr_lastnight~=0));
        local_coef_g = regress(rtxm_today(good & dd_cf_yesterday~=0),dd_cf_yesterday(good & dd_cf_yesterday~=0));
        local_coef_h = regress(rtxm_today(good & dd_cf_yesterday_afternoon~=0),dd_cf_yesterday_afternoon(good & dd_cf_yesterday_afternoon~=0));
        local_coef_i = regress(rtxm_today(good & dd_cf_lastnight~=0),dd_cf_lastnight(good & dd_cf_lastnight~=0));

        coef_d(k) = coef_d(k) * RETENTION + local_coef_d * (1-RETENTION); 
        coef_e(k) = coef_e(k) * RETENTION + local_coef_e * (1-RETENTION);
        coef_f(k) = coef_f(k) * RETENTION + local_coef_f * (1-RETENTION);
        coef_g(k) = coef_g(k) * RETENTION + local_coef_g * (1-RETENTION);
        coef_h(k) = coef_h(k) * RETENTION + local_coef_h * (1-RETENTION);
        coef_i(k) = coef_i(k) * RETENTION + local_coef_i * (1-RETENTION);

        if i == 1
            coef_d(k) = local_coef_d;
            coef_e(k) = local_coef_e;
            coef_f(k) = local_coef_f;
            coef_g(k) = local_coef_g;
            coef_h(k) = local_coef_h;
            coef_i(k) = local_coef_i;
        end
    end
    % --------------------------------------------------------------------

    % Load in Testing Data
    [t_rr_yesterday, t_rr_yesterday_afternoon, t_rr_lastnight, t_cf_yesterday, t_cf_yesterday_afternoon, t_cf_lastnight, t_vol_yesterday_change, t_rtxm_today, t_r_today]...
        = return_data(test_month, test_month, true);

    % Divide Data on Threshold
    [dt_rr_yesterday, dt_rr_yesterday_afternoon, dt_rr_lastnight, dt_cf_yesterday, dt_cf_yesterday_afternoon, dt_cf_lastnight]...
        = divide_data_on_threshold(t_rr_yesterday, t_rr_yesterday_afternoon, t_rr_lastnight, t_cf_yesterday, t_cf_yesterday_afternoon, t_cf_lastnight, t_vol_yesterday_change, VOL_UP_THRESHOLD, VOL_DOWN_THRESHOLD);

    t_tc_local_open = loaddata("hlfspread_bytm",test_month,test_month,1);
    t_tc_local_close = loaddata("hlfspread_bytm",test_month,test_month,4);
    t_mid_open = loaddata("mid_open",test_month,test_month);
    t_mid_close = loaddata("mid_close",test_month,test_month);

    t_tc_local_open = t_tc_local_open(:,2:end);
    t_tc_local_close = t_tc_local_close(:,2:end);
    t_mid_open = t_mid_open(:,2:end);
    t_mid_close = t_mid_close(:,2:end);

    t_good = loaddata("good_now",test_month,test_month);
    t_good = t_good(:, 1:end-1) & t_good(:,2:end) == 1;
    t_good = t_good...
        & ~isnan(t_rr_yesterday)...
        & ~isnan(t_rr_yesterday_afternoon)...
        & ~isnan(t_rr_lastnight)...
        & ~isnan(t_cf_yesterday)...
        & ~isnan(t_cf_yesterday_afternoon)...
        & ~isnan(t_cf_lastnight)...
        & ~isnan(t_vol_yesterday_change)...
        & ~isnan(t_rtxm_today) & ~isnan(t_r_today) & ~isnan(t_tc_local_open) & ~isnan(t_tc_local_close) & ~isnan(t_mid_open) & ~isnan(t_mid_close);

    d1 = dt_rr_yesterday(:,:,1);
    d2 = dt_rr_yesterday(:,:,2);
    d3 = dt_rr_yesterday(:,:,3);
    e1 = dt_rr_yesterday_afternoon(:,:,1);
    e2 = dt_rr_yesterday_afternoon(:,:,2);
    e3 = dt_rr_yesterday_afternoon(:,:,3);
    f1 = dt_rr_lastnight(:,:,1);
    f2 = dt_rr_lastnight(:,:,2);
    f3 = dt_rr_lastnight(:,:,3);
    g1 = dt_cf_yesterday(:,:,1);
    g2 = dt_cf_yesterday(:,:,2);
    g3 = dt_cf_yesterday(:,:,3);
    h1 = dt_cf_yesterday_afternoon(:,:,1);
    h2 = dt_cf_yesterday_afternoon(:,:,2);
    h3 = dt_cf_yesterday_afternoon(:,:,3);
    i1 = dt_cf_lastnight(:,:,1);
    i2 = dt_cf_lastnight(:,:,2);
    i3 = dt_cf_lastnight(:,:,3);

    ff = ...
        (coef_d(1) * d1(t_good)) + coef_d(2) * d2(t_good) + coef_d(3) * d3(t_good) +...
        (coef_e(1) * e1(t_good)) + coef_e(2) * e2(t_good) + coef_e(3) * e3(t_good) +...
        (coef_f(1) * f1(t_good)) + coef_f(2) * f2(t_good) + coef_f(3) * f3(t_good) +...
        (coef_g(1) * g1(t_good)) + coef_g(2) * g2(t_good) + coef_g(3) * g3(t_good) +...
        (coef_h(1) * h1(t_good)) + coef_h(2) * h2(t_good) + coef_h(3) * h3(t_good) +...
        (coef_i(1) * i1(t_good)) + coef_i(2) * i2(t_good) + coef_i(3) * i3(t_good);

    yy = t_rtxm_today(t_good);

    result = iccalc(ff,yy);

    % Trading Algorithm ---------------------------------------------
    for j = 1:size(t_good,2)

        good_today = t_good(:,j);

        forecast =...
            (coef_d(1) * dt_rr_yesterday(good_today,j,1)) + coef_d(2) * dt_rr_yesterday(good_today,j,2) + coef_d(3) * dt_rr_yesterday(good_today,j,3) +...
            (coef_e(1) * dt_rr_yesterday(good_today,j,1)) + coef_e(2) * dt_rr_yesterday_afternoon(good_today,j,2) + coef_e(3) * dt_rr_yesterday_afternoon(good_today,j,3) +...
            (coef_f(1) * dt_rr_lastnight(good_today,j,1)) + coef_f(2) * dt_rr_lastnight(good_today,j,2) + coef_f(3) * dt_rr_lastnight(good_today,j,3) +...
            (coef_g(1) * dt_cf_yesterday(good_today,j,1)) + coef_g(2) * dt_cf_yesterday(good_today,j,2) + coef_g(3) * dt_cf_yesterday(good_today,j,3) +...
            (coef_h(1) * dt_cf_yesterday_afternoon(good_today,j,1)) + coef_h(2) * dt_cf_yesterday_afternoon(good_today,j,2) + coef_h(3) * dt_cf_yesterday_afternoon(good_today,j,3) +...
            (coef_i(1) * dt_cf_lastnight(good_today,j,1)) + coef_i(2) * dt_cf_lastnight(good_today,j,2) + coef_i(3) * dt_cf_lastnight(good_today,j,3);

        forecast = (abs(forecast) - TC) .* sign(forecast);
        forecast(abs(forecast)<TC) = 0;

        [ NA, forecast_index] = sort(forecast);

        % Trading Costs and Return Variables
        day_returns = t_r_today(good_today,j);
        tc_open = t_tc_local_open(good_today,j);
        tc_close = t_tc_local_close(good_today,j);
        mid_open = t_mid_open(good_today,j);
        mid_close = t_mid_close(good_today,j);
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

        % Reverse engineer the indices to the original stock indices
        original_idx_short = find(good_today);
        original_idx_short = original_idx_short(idx_short);
        original_idx_long = find(good_today);
        original_idx_long = original_idx_long(idx_long);

        % Update stock trade count
        stock_trade_count([original_idx_long; original_idx_short]) = stock_trade_count([original_idx_long; original_idx_short]) + 1;

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

function [rr_yesterday, rr_yesterday_afternoon, rr_lastnight, cf_yesterday, cf_yesterday_afternoon, cf_lastnight, vol_yesterday_change, rtxm_today, r_today]...
    = return_data(start_month, end_month, test)

    rtxm_day = loaddata("rtxm_byti",start_month,end_month,2);
    rr_day = loaddata("rrirpnxm_byti",start_month,end_month,2);
    rr_afternoon = loaddata("rrirpnxm_byti",start_month,end_month,5);
    rr_night = loaddata("rrirpnxm_byti",start_month,end_month,1);
    cf_day = loaddata("cfirpnxm_byti",start_month,end_month,2);
    cf_afternoon = loaddata("cfirpnxm_byti",start_month,end_month,5);
    cf_night = loaddata("cfirpnxm_byti",start_month,end_month,1);
    vol_day = loaddata("volall_day",start_month,end_month,1);
    vol_morning = loaddata("volcum_bytm",start_month,end_month,2); 
    vol_afternoon = vol_day - vol_morning;
    
    rr_yesterday = rr_day(:,1:end-1);
    rr_yesterday_afternoon = rr_afternoon(:,1:end-1);
    rr_lastnight = rr_night(:,2:end);
    cf_yesterday = cf_day(:,1:end-1);
    cf_yesterday_afternoon = cf_afternoon(:,1:end-1);
    cf_lastnight = cf_night(:,2:end);
    vol_yesterday_change = (vol_afternoon(:,1:end-1) - vol_morning(:,1:end-1)) ./ vol_morning(:,1:end-1);
    rtxm_today = rtxm_day(:,2:end);

    r_today = 0;
    if test
        r_day = loaddata("r_byti",start_month,end_month,2);
        r_today = r_day(:,2:end);
    end
end

function [d_rr_yesterday,d_rr_yesterday_afternoon,d_rr_lastnight,d_cf_yesterday,d_cf_yesterday_afternoon,d_cf_lastnight]...
     = divide_data_on_threshold(rr_yesterday, rr_yesterday_afternoon, rr_lastnight, cf_yesterday, cf_yesterday_afternoon, cf_lastnight,threshold_var,threshold_up,threshold_down)

    % Define the conditions as a cell array
    conditions = {
        threshold_var > threshold_up,        % Condition for layer 1
        threshold_var < threshold_down,      % Condition for layer 2
        threshold_var <= threshold_up & ...
        threshold_var >= threshold_down     % Condition for layer 3
    };

    % Initialize the 3D array
    d_rr_yesterday = zeros(size(rr_yesterday, 1), size(rr_yesterday, 2), 3);
    d_rr_yesterday_afternoon = zeros(size(rr_yesterday_afternoon, 1), size(rr_yesterday_afternoon, 2), 3);
    d_rr_lastnight = zeros(size(rr_lastnight, 1), size(rr_lastnight, 2), 3);
    d_cf_yesterday = zeros(size(cf_yesterday, 1), size(cf_yesterday, 2), 3);
    d_cf_yesterday_afternoon = zeros(size(cf_yesterday_afternoon, 1), size(cf_yesterday_afternoon, 2), 3);
    d_cf_lastnight = zeros(size(cf_lastnight, 1), size(cf_lastnight, 2), 3);

    % Apply conditions using a loop
    for k = 1:3
        d_rr_yesterday(:, :, k) = rr_yesterday .* conditions{k};
        d_rr_yesterday_afternoon(:, :, k) = rr_yesterday_afternoon .* conditions{k};
        d_rr_lastnight(:, :, k) = rr_lastnight .* conditions{k};
        d_cf_yesterday(:, :, k) = cf_yesterday .* conditions{k};
        d_cf_yesterday_afternoon(:, :, k) = cf_yesterday_afternoon .* conditions{k};
        d_cf_lastnight(:, :, k) = cf_lastnight .* conditions{k};
    end
end

% ===================================================================