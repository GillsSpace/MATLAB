% Parameters and Hyperparameter ===============================================================================================
start_month = 201001;
end_month = 202212;

INITIAL_BALANCE = 10000;        % 10k
TC = 0.00055;                   % 5.5 bps

% Neural Network Hyperparameter
loss_function = 'mse';

options = trainingOptions("adam", ...
    LearnRateSchedule = "polynomial", ...
    InitialLearnRate=0.0000001,...
    MaxEpochs = 10, ... 
    MiniBatchSize = 128, ...
    ExecutionEnvironment = "cpu", ...
    Verbose=false, ...
    Plots = "none");

NN = dlnetwork([
    featureInputLayer(6, "Name", "InputLayer")                                              % Input Layer with 6 features
    fullyConnectedLayer(32, "Name", "HiddenLayer1", "WeightsInitializer", "narrow-normal")  % Hidden Layer with 32 neurons
    reluLayer("Name", "ReLU")                                                               % ReLU Activation Layer
    % dropoutLayer(0.2, "Name", "Dropout")                                                  % Dropout Layer with 20% dropout rate
    fullyConnectedLayer(1, "Name", "OutputLayer", "WeightsInitializer", "narrow-normal")    % Output Layer with 2 neurons
]);
% =============================================================================================================================

% Initialize Variables ========================================================================================================
total_months = calculate_total_months(start_month, end_month);
balance = INITIAL_BALANCE;

% Initialize Results Arrays:
monthly_mr = zeros(1,total_months);
monthly_rtxm_afternoon_data_balance= zeros(1,total_months);
% monthly_balance = zeros(1,total_months-ROLLOVER);
% monthly_traded_mr = zeros(1,total_months-ROLLOVER);
% 
% traded_ff = NaN(STOCKS_EACH_DAY,31,total_months-ROLLOVER);
% traded_yy = NaN(STOCKS_EACH_DAY,31,total_months-ROLLOVER);
% =============================================================================================================================

% Main Loop ===================================================================================================================
tic;

for i = 1:total_months

    i_month = increment_month(start_month, i - 1);

    [X, Y, Y_raw] = prepare_month_data(i_month);

    [F, F_labels, F_total_long, F_total_short, F_total, F_correct_long, F_correct_short, F_correct, F_acc_long, F_acc_short, F_acc, guess_balance, data_balance]...
        = calculate_statistics(NN, X, Y);

    fprintf("Month: %d (iteration: %d)\n", i_month,i);
    fprintf("Accuracy      : %2.2f%% (%d/%d correct predictions)\n", F_acc, F_correct, F_total);
    fprintf("Accuracy Long : %2.2f%% (%d/%d correct predictions)\n", F_acc_long, F_correct_long, F_total_long);
    fprintf("Accuracy Short: %2.2f%% (%d/%d correct predictions)\n", F_acc_short, F_correct_short, F_total_short);
    % fprintf("Accuracy 50%%: %.2f%%\n", acc_50);
    % fprintf("Accuracy 20%%: %.2f%%\n", acc_20);
    % fprintf("Accuracy 5%% : %.2f%%\n", acc_5);
    fprintf("Guess Balance: %.2f%%\n", guess_balance);
    fprintf("Data Balance : %.2f%%\n", data_balance)

    monthly_result = iccalc(F,Y);

    monthly_mr(i) = monthly_result.mr;
    monthly_rtxm_afternoon_data_balance(i) = data_balance;

    fprintf("MR : %.2f bps\n\n", monthly_mr(i)*10000)

    fprintf("-----------------------------------------------------------------\n\n")

    NN = trainnet(X, Y, NN, loss_function, options);

end

toc
% =============================================================================================================================

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

function [X, Y, Y_raw] = prepare_month_data(i_month)
    
    good_today = loaddata('good_now', i_month, i_month);
    rtxm_morning = loaddata('rtxm_byti', i_month, i_month, 3);
    rtxm_lunch = loaddata('rtxm_byti', i_month, i_month, 4);
    rtxmcf_morning = loaddata('cfirpnxm_byti', i_month, i_month, 3);
    rtxmcf_lunch = loaddata('cfirpnxm_byti', i_month, i_month, 4);
    rtxmrr_morning = loaddata('rrirpnxm_byti', i_month, i_month, 3);
    rtxmrr_lunch = loaddata('rrirpnxm_byti', i_month, i_month, 4);

    rtxm_afternoon = loaddata('rtxm_byti', i_month, i_month, 5);
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

    %Generate Y_real
    Y_raw = r_afternoon(valid_rows);
end

function X_norm = normalize_feature(feature)
    X_norm = (feature - mean(feature)) / std(feature);
end

function [F, F_labels,...
    F_total_long, F_total_short, F_total,...
    F_correct_long, F_correct_short, F_correct,...
    F_acc_long, F_acc_short, F_acc,...
    guess_balance, data_balance]...
    = calculate_statistics(NN, X, Y)

    F = predict(NN,X);
    F_labels = double(F>=0);
    Y_labels = double(Y>=0);

    F_total_long = sum(F_labels == 1); %How many long GUESSES do we make?
    F_total_short = sum(F_labels == 0); %How many short GUESSES do we make?
    F_total = F_total_long + F_total_short;

    F_correct_long = sum(F_labels == Y_labels & F_labels == 1); %Are we correct when we GUESS long?
    F_correct_short = sum(F_labels == Y_labels & F_labels == 0); %Are we correct when we GUESS short?
    F_correct = F_correct_long + F_correct_short;

    F_acc_long = F_correct_long / F_total_long * 100;
    F_acc_short = F_correct_short / F_total_short * 100;
    F_acc = F_correct / F_total * 100;

    guess_balance = F_total_long / F_total * 100;
    data_balance = sum(Y_labels == 1) / F_total * 100;

    % avg = mean(F);
    % sd = std(F);

    % [ NA, idx] = sort(F); 
    % var_50 = round(F_total / 4);
    % var_20 = round(F_total / 10);
    % var_5 = round(F_total / 40);
    % F_acc_50 = sum(Y(idx>F_total-var_50 | idx<var_50) == F_labels(idx>F_total-var_50 | idx<var_50)) / (F_total*0.5) * 100;
    % F_acc_20 = sum(Y(idx>F_total-var_20 | idx<var_20) == F_labels(idx>F_total-var_20 | idx<var_20)) / (F_total*0.2) * 100;
    % F_acc_5 = sum(Y(idx>F_total-var_5 | idx<var_5) == F_labels(idx>F_total-var_5 | idx<var_5)) / (F_total*0.05) * 100;

end

% ==============================================================