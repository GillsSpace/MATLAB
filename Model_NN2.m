% Parameters and Hyperparameters ===============================
start_month = 201001;
end_month = 202212;

INITIAL_BALANCE = 10000;        % 10k
TC = 0.0005;                    % 10 bps
STOCKS_EACH_DAY = 30;

% Neural Network Hyperparameter
loss_function = 'mse';

options = trainingOptions("adam", ...
    LearnRateSchedule = "polynomial", ...
    MaxEpochs = 10, ... 
    MiniBatchSize = 128, ...
    ExecutionEnvironment = "cpu", ...
    Verbose=false, ...
    Plots = "none");

NN = [
    featureInputLayer(3, "Name", "InputLayer")
    fullyConnectedLayer(32, "Name", "HiddenLayer1","WeightsInitializer", "he") 
    reluLayer("Name", "ReLU")
    dropoutLayer(0.2, "Name", "Dropout") 
    fullyConnectedLayer(1, "Name", "OutputLayer","WeightsInitializer", "glorot")
    sigmoidLayer("Name", "SigmoidOutput") 
];
NN = dlnetwork(NN);

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

    [accuracy, correct_predictions, total_predictions, balance, mean, sd, acc_50, acc_20, acc_5, labels, predictions] = calculate_statistics(NN, X_data, Y_data);

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
    rtxm_afternoon = loaddata('rtxm_byti', i_month, i_month, 5);
    vol_morning = loaddata('volcum_bytm', i_month, i_month, 2);

    r_afternoon = loaddata('r_byti', i_month, i_month, 5);

    valid_rows = good_today & all(~isnan([rtxm_morning, rtxm_lunch, vol_morning, rtxm_afternoon, r_afternoon]), 2);

    % Normalize and Generate X
    X_1 = normalize_feature(rtxm_morning(valid_rows));
    X_2 = normalize_feature(rtxm_lunch(valid_rows));
    X_3 = normalize_feature(vol_morning(valid_rows));
    X = [X_1, X_2, X_3];

    % Generate Y
    Y = rtxm_afternoon(valid_rows);
    Y = Y > 0;
    Y = double(Y);
    Y_real = r_afternoon(valid_rows);
end

function X_norm = normalize_feature(feature)
    X_norm = (feature - mean(feature)) / std(feature);
end

function [accuracy, correct_predictions, total_predictions, balance, avg, sd, acc_50, acc_20, acc_5, predicted_labels, predictions] = calculate_statistics(NN, X, Y)
    predictions = predict(NN,X);
    predicted_labels = predictions > 0.5;

    correct_predictions = sum(predicted_labels == Y);
    total_predictions = numel(Y);
    accuracy = correct_predictions / total_predictions * 100;

    balance = sum(predicted_labels) / total_predictions * 100;
    avg = mean(predictions);
    sd = std(predictions);

    [ NA, idx] = sort(predictions); 
    var_50 = round(total_predictions / 4);
    var_20 = round(total_predictions / 10);
    var_5 = round(total_predictions / 40);
    acc_50 = sum(Y(idx>total_predictions-var_50 | idx<var_50) == predicted_labels(idx>total_predictions-var_50 | idx<var_50)) / (total_predictions*0.5) * 100;
    acc_20 = sum(Y(idx>total_predictions-var_20 | idx<var_20) == predicted_labels(idx>total_predictions-var_20 | idx<var_20)) / (total_predictions*0.2) * 100;
    acc_5 = sum(Y(idx>total_predictions-var_5 | idx<var_5) == predicted_labels(idx>total_predictions-var_5 | idx<var_5)) / (total_predictions*0.05) * 100;

end

% ==============================================================