% Hyper-parameters: =============================================
START_MONTH = 201001;
END_MONTH = 202212;
ROLLOVER = 6;
INITIAL_BALANCE = 10000;        % 10k
TC = 0.00055;                   % 5.5 bps
STOCKS_EACH_DAY = 30;
% ==============================================================

% Initialize Variables ===============================================
total_months = calculate_total_months(START_MONTH, END_MONTH);


% Main Loop ====================================================
tic;

for i = 1:total_months-ROLLOVER

    i_month = increment_month(START_MONTH, i - 1);

    [X, Y, Y_raw] = prepare_data(i_month, i_month + ROLLOVER);

    coef_a = regress(Y,X)


end




% Functions ====================================================

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

function [X,Y,Y_raw] = prepare_data(month_start,month_end)
    
    good= loaddata('good_now', month_start, month_end);

    % Load data from database -----------------------------------------
    rtxm_night = loaddata('rtxm_byti', month_start, month_end, 1);
    rtxm_day = loaddata('rtxm_byti', month_start, month_end, 2);
    rtxm_morning = loaddata('rtxm_byti', month_start, month_end, 3);
    rtxm_lunch = loaddata('rtxm_byti', month_start, month_end, 4);
    rtxm_afternoon = loaddata('rtxm_byti', month_start, month_end, 5);

    rtxmcf_night = loaddata('cfirpnxm_byti', month_start, month_end, 1);
    rtxmcf_day = loaddata('cfirpnxm_byti', month_start, month_end, 2);
    rtxmcf_morning = loaddata('cfirpnxm_byti', month_start, month_end, 3);
    rtxmcf_lunch = loaddata('cfirpnxm_byti', month_start, month_end, 4);
    rtxmcf_afternoon = loaddata('cfirpnxm_byti', month_start, month_end, 5);

    rtxmrr_night = loaddata('rrirpnxm_byti', month_start, month_end, 1);
    rtxmrr_day = loaddata('rrirpnxm_byti', month_start, month_end, 2);
    rtxmrr_morning = loaddata('rrirpnxm_byti', month_start, month_end, 3);
    rtxmrr_lunch = loaddata('rrirpnxm_byti', month_start, month_end, 4);
    rtxmrr_afternoon = loaddata('rrirpnxm_byti', month_start, month_end, 5);

    r_night = loaddata('r_byti', month_start, month_end, 1);
    r_day = loaddata('r_byti', month_start, month_end, 2);
    r_afternoon = loaddata('r_byti', month_start, month_end,5);
    % -----------------------------------------------------------------
    

    valid_rows = good & all(~isnan([rtxm_morning, rtxm_lunch, rtxm_afternoon, rtxmcf_morning, rtxmcf_lunch, rtxmrr_morning, rtxmrr_lunch, r_afternoon]), 2);

    % Generate X
    X_1 = rtxm_morning(valid_rows);
    X_2 = rtxm_lunch(valid_rows);
    X_3 = rtxmcf_morning(valid_rows);
    X_4 = rtxmcf_lunch(valid_rows);
    X_5 = rtxmrr_morning(valid_rows);
    X_6 = rtxmrr_lunch(valid_rows);
    X = cat(3,X_1, X_2, X_3, X_4, X_5, X_6);

    % Generate Y
    Y = rtxm_afternoon(valid_rows);

    % Generate Y_real
    Y_raw = r_afternoon(valid_rows);

end