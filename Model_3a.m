% Data Hyper-parameters =============================================
start_month = 201801;
end_month = 202212;
ROLLOVER = 6;
INITIAL_BALANCE = 10000;        %10 k
TC = 0.0010;                    %10 bps
STOCKS_EACH_DAY = 30;
% ===================================================================

% Initialize Variables ===============================================
total_months = end_month - start_month;
years = floor(total_months/100);
total_months = total_months - 100*years + 12*years;
balance = INITIAL_BALANCE;

% Initialize Results Arrays:
monthly_mr = zeros(1,total_months-ROLLOVER);
monthly_balance = zeros(1,total_months-ROLLOVER);
monthly_traded_mr = zeros(1,total_months-ROLLOVER);

traded_ff = NaN(STOCKS_EACH_DAY,31,total_months-ROLLOVER);
traded_yy = NaN(STOCKS_EACH_DAY,31,total_months-ROLLOVER);
% ===================================================================

% Warning Suppression:
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

% Main Training and Testing Loop ===================================
i = 1;
while i <= total_months - ROLLOVER
    
    %Loop variables -----------------------------------------------
    i_start = months_add(start_month,i-1);
    i_end   = months_add(start_month,ROLLOVER+i-2);
    i_test  = months_add(start_month,ROLLOVER+i-1);
    % ------------------------------------------------------------

    % Load Data ---------------------------------------------------
    rtxm_day        = loaddata('rtxm_byti',i_start,i_end,2);
    rtxm_night      = loaddata('rtxm_byti',i_start,i_end,1);
    vol_day         = loaddata("volall_day",i_start,i_end,1);
    vol_morning     = loaddata("volcum_bytm",i_start,i_end,2); 
    vol_afternoon   = vol_day - vol_morning;
    good            = loaddata('good_now', i_start, i_end);
    nup_day         = loaddata('nuptrds_bytm', i_start, i_end);  % Up-trades
    ndown_day       = loaddata('ndowntrds_bytm', i_start, i_end);  % Down-trades
    % ------------------------------------------------------------
    
    % Form Inputs & Outputs ---------------------------------------
    rtxm_day1 = rtxm_day(1:end-2,:);
    rtxm_day2 = rtxm_day(2:end-1,:);
    rtxm_night1 = rtxm_night(1:end-2,:);
    rtxm_night2 = rtxm_night(2:end-1,:);
    rtxm_today = rtxm_day(3:end,:);
    % -------------------------------------------------------------





    

    i = i + 1;

end
% ===================================================================
