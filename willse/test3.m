%X_r = loaddata("r_byti",201001,201001,[1:5]);
%X_rt = loaddata("rt_byti",201001,201001,[1:5]);
%X_tr = loaddata("tr_byti",201001,201001,[1:5]);

%X_r_1 = X_r(1,:,:);
%X_rt_1 = X_rt(1,:,:);
%X_tr_1 = X_tr(1,:,:);

% X_2 = X1(:,:,3) + X1(:,:,[4]) + X1(:,:,[5]);

X = loaddata("vol_bytm",201001,201002,[1:4]);
X = X(1,1,:);

Y = loaddata("volcum_bytm",201001,201002,[1:4]);
Y = Y(1,1,:);

Z = loaddata("volall_day",201001,201002,[1]);
Z = Z(1,1,:);