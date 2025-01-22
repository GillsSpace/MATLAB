% Parameters and Hyperparameters ===============================
start_month = 201001;
end_month = 202212;

INITIAL_BALANCE = 10000;        % 10k
TC = 0.0005;                    % 10 bps
STOCKS_EACH_DAY = 30;

% Neural Network Hyperparameter
loss_function = 'crossentropy';

options = trainingOptions("adam", ...
    LearnRateSchedule = "polynomial", ...
    MaxEpochs = 5, ... 
    MiniBatchSize = 128, ...
    ExecutionEnvironment = "cpu", ...
    Verbose=true, ...
    Plots = "none");

NN = dlnetwork([
    featureInputLayer(6, "Name", "InputLayer") % Two input features: x and y
    fullyConnectedLayer(32, "Name", "HiddenLayer1", "WeightsInitializer", "he")
    reluLayer("Name", "ReLU")
    dropoutLayer(0.2, "Name", "Dropout")
    fullyConnectedLayer(1, "Name", "OutputLayer", "WeightsInitializer", "glorot") % Single output (for regression)
]);

% ==============================================================

% Initialize Variables ===============================================
total_months = calculate_total_months(start_month, end_month);
balance = INITIAL_BALANCE;

% Initialize Results Arrays:
monthly_mr = zeros(1,total_months);
% monthly_balance = zeros(1,total_months-ROLLOVER);
% monthly_traded_mr = zeros(1,total_months-ROLLOVER);
% 
% traded_ff = NaN(STOCKS_EACH_DAY,31,total_months-ROLLOVER);
% traded_yy = NaN(STOCKS_EACH_DAY,31,total_months-ROLLOVER);
% ===================================================================

% Main Loop ====================================================
tic;

for i = 1:total_months

    i_month = increment_month(start_month, i - 1);

    [X_data, Y_data, Y_real] = prepare_month_data(i_month);

    [predictions, labels, total_predictions, correct_predictions, accuracy, balance, mean, sd, acc_50, acc_20, acc_5] = calculate_statistics(NN, X_data, Y_data);

    fprintf("Accuracy    : %.2f%% (%d/%d correct predictions)\n", accuracy, correct_predictions, total_predictions);
    fprintf("Accuracy 50%%: %.2f%%\n", acc_50);
    fprintf("Accuracy 20%%: %.2f%%\n", acc_20);
    fprintf("Accuracy 5%% : %.2f%%\n", acc_5);
    fprintf("Balance: %.2f%%\n", balance);
    fprintf("Mean: %.2f // SD: %.2f\n\n" , mean,sd);

    labels = double(labels);
    labels(labels<0.5) = -1;

    monthly_result = iccalc(labels,Y_real);
    monthly_mr(i) = monthly_result.mr;

    NN = trainnet(X_data, Y_data, NN, loss_function, options);

end

toc
% ==============================================================

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

function [X, Y, Y_real] = prepare_month_data(i_month)
    
    good_today = loaddata('good_now', i_month, i_month);
    rtxm_morning = loaddata('rtxm_byti', i_month, i_month, 3);
    rtxm_lunch = loaddata('rtxm_byti', i_month, i_month, 4);
    rtxmcf_morning = loaddata('cfirpnxm_byti', i_month, i_month, 3);
    rtxmcf_lunch = loaddata('cfirpnxm_byti', i_month, i_month, 4);
    rtxmrr_morning = loaddata('rrirpnxm_byti', i_month, i_month, 3);
    rtxmrr_lunch = loaddata('rrirpnxm_byti', i_month, i_month, 4);

    rtxm_afternoon = loaddata('rtxm_byti', i_month, i_month, 5);
    %vol_morning = loaddata('volcum_bytm', i_month, i_month, 2);

    r_afternoon = loaddata('r_byti', i_month, i_month, 5);

    valid_rows = good_today & all(~isnan([rtxm_morning, rtxm_lunch, rtxm_afternoon, rtxmcf_morning, rtxmcf_lunch, rtxmrr_morning, rtxmrr_lunch, r_afternoon]), 2);

    % Normalize and Generate X
    X_1 = rtxm_morning(valid_rows);
    X_2 = rtxm_lunch(valid_rows);
    X_3 = rtxmcf_morning(valid_rows);
    X_4 = rtxmcf_lunch(valid_rows);
    X_5 = rtxmrr_morning(valid_rows);
    X_6 = rtxmrr_lunch(valid_rows);
    X = [X_1, X_2, X_3, X_4, X_5, X_6];

    % Generate Y
    Y = rtxm_afternoon(valid_rows);
    Y = Y > 0;
    Y = double(Y);
    Y_real = r_afternoon(valid_rows);
end

function X_norm = normalize_feature(feature)
    X_norm = (feature - mean(feature)) / std(feature);
end

function [F, F_labels, F_count, F_correct, accuracy, balance, avg, sd, F_acc_50, F_acc_20, F_acc_5] = calculate_statistics(NN, X, Y)
    F = predict(NN,X);
    F_labels = F > 0.5;

    F_correct = sum(F_labels == Y);
    F_count = numel(Y);
    accuracy = F_correct / F_count * 100;

    balance = sum(F_labels) / F_count * 100;
    avg = mean(F);
    sd = std(F);

    [ NA, idx] = sort(F); 
    var_50 = round(F_count / 4);
    var_20 = round(F_count / 10);
    var_5 = round(F_count / 40);
    F_acc_50 = sum(Y(idx>F_count-var_50 | idx<var_50) == F_labels(idx>F_count-var_50 | idx<var_50)) / (F_count*0.5) * 100;
    F_acc_20 = sum(Y(idx>F_count-var_20 | idx<var_20) == F_labels(idx>F_count-var_20 | idx<var_20)) / (F_count*0.2) * 100;
    F_acc_5 = sum(Y(idx>F_count-var_5 | idx<var_5) == F_labels(idx>F_count-var_5 | idx<var_5)) / (F_count*0.05) * 100;

end

% ==============================================================