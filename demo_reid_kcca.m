%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% (c) Copyright 2012-14  Anonymous Authors ICDSC14 #23
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear;clc; close all force;
addpath('kcca_package');

%% Plot settings
set(0,'DefaultFigureWindowStyle','docked');
colors = repmat('rgbkmcyrgbk',1,200);
markers = repmat('+o*.xsd^v<>ph',1,200);

%% Load data%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
datasetname='VIPeR'; %VIPeR %PRID
ccaON = 0; %% can be turned off since it is slow.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if strcmp('VIPeR',datasetname)
   load data/VIPeR_split.mat
   maxNumTemplate = 1;
   num_gallery = 316;
   num_train = 316;
   num_test = 316;
end
if strcmp('PRID',datasetname)
   load data/PRID_split.mat
   maxNumTemplate = 1;
   num_gallery = 649;
   num_train = 100;
   num_test = 100;
end

%% KCCA/CCA Parameters
eta_kcca = 1;
kapa_kcca = 0.5;
kapa_cca = 1;
nTrial = 10;
%%%%%%%%%%%%%%%%%%%%%

%% Initialize cmc matrix
cmc_kcca = zeros(num_gallery,3);
cmc_kcca(:,1) = 1:num_gallery;
cmc_cca = zeros(num_gallery,3);
cmc_cca(:,1) = 1:num_gallery;
cmc_nn = zeros(num_gallery,3);
cmc_nn(:,1) = 1:num_gallery;

for nt=1:nTrial
   disp(['>Computing Trial ' num2str(nt) '...' ]);
   train_a = trials(nt).featAtrain;
   train_b = trials(nt).featBtrain;
   test_a = trials(nt).featAtest;
   test_b = trials(nt).featBtest;
   
   %% Permutation indices
   idxTrain_a = 1:num_train;
   idxTrain_b = idxTrain_a;
   idxProbe = randperm(num_test);
   idxGallery = randperm(num_gallery);
   
   %% Permutation on Train, Gallery and Test set
   test_a = test_a(:,idxProbe);
   test_b = test_b(:,idxGallery);
   train_a = train_a(:,idxTrain_a);
   train_b = train_b(:,idxTrain_b);
   
   disp('>Applying Kernel to Train and Test...');
   %% Applying Kernel
   [train_a_ker, omegaA] = kernel_expchi2(train_a',train_a');
   [train_b_ker, omegaB] = kernel_expchi2(train_b',train_b');
   [test_a_ker] = kernel_expchi2(test_a',train_a',omegaA);
   [test_b_ker] = kernel_expchi2(test_b',train_b',omegaB);
   
   if ccaON
      disp('>Computing CCA on the training set...');
      %% Computing CCA  on the training set
      [Wx_cca Wy_cca r] = cca(train_b,train_a,kapa_cca);
      Wx_cca = real(Wx_cca);
      Wy_cca = real(Wy_cca);
   end
   
   disp('>Computing KCCA  on the training set...');
   %% Computing KCCA  on the training set
   [Wx, Wy, r] = kcanonca_reg_ver2(train_b_ker,train_a_ker,eta_kcca,kapa_kcca,0,0);
   [train_a_ker,test_a_ker,train_b_ker,test_b_ker] = center_kcca(train_a_ker,test_a_ker,train_b_ker,test_b_ker);
   
   disp('>Projecting the test data...');
   %% Projecting data
   if ccaON
      test_b_proj = (test_b'*Wx_cca);
      test_a_proj = (test_a'*Wy_cca);
   end
   test_b_ker_proj = test_b_ker*Wx;
   test_a_ker_proj = test_a_ker*Wy;
   
   %%projecting train
   train_b_ker_proj = train_b_ker*Wy;
   train_a_ker_proj = train_a_ker*Wy;
   
   myscore = zeros(size(test_b_ker_proj,1),10);
   allTrain = [train_a_ker_proj; train_b_ker_proj];
   disp('>Computing dual score...');
   for p=1:size(test_b_ker_proj,1)
      finalScore = score_kcca(:,p);
      [sortScore sortIndex] = sort(finalScore);
      for g=1:10
         tic
         myscore(p,g) = dualSimiliarityReid(test_b_ker_proj(p,:),test_a_ker_proj(sortIndex(g),:),allTrain );
         toc
      end
   end
   
   disp('>Computing distances...');
   %% Compute distances
   if ccaON
      score_cca = pdist2(test_b_proj,test_a_proj,'cosine');
   end
   score_kcca = pdist2(test_b_ker_proj,test_a_ker_proj,'cosine');
   score_nn = pdist2(test_b',test_a','euclidean');
   
   %% Re-ordering original PRID labels
   if strcmp('PRID',datasetname)
      idxProbe = trials(nt).labels_probe(idxProbe);
      idxGallery = trials(nt).labels_gallery(idxGallery);
   end
   
   disp('>Evaluating results...');
   %% Compute CMC for NN, CCA and KCCA
   cmcCurrent = zeros(num_gallery,3);
   cmcCurrent(:,1) = 1:num_gallery;
   for k=1:num_test
      finalScore = score_kcca(:,k);
      [sortScore sortIndex] = sort(finalScore);
      [cmc_kcca cmcCurrent] = evaluateCMC_demo(idxProbe(k),idxGallery(sortIndex),cmc_kcca,cmcCurrent);
   end
   plotCurrentTrial
   if ccaON
      cmcCurrent = zeros(num_gallery,3);
      cmcCurrent(:,1) = 1:num_gallery;
      for k=1:num_test
         finalScore = score_cca(:,k);
         [sortScore sortIndex] = sort(finalScore);
         [cmc_cca cmcCurrent] = evaluateCMC_demo(idxProbe(k),idxGallery(sortIndex),cmc_cca,cmcCurrent);
      end
   end
   cmcCurrent = zeros(num_gallery,3);
   cmcCurrent(:,1) = 1:num_gallery;
   for k=1:num_test
      finalScore = score_nn(:,k);
      [sortScore sortIndex] = sort(finalScore);
      [cmc_nn cmcCurrent] = evaluateCMC_demo(idxProbe(k),idxGallery(sortIndex),cmc_nn,cmcCurrent);
   end
   
end

figure(1);hold on;plotCMCcurve(cmc_nn,'g','',datasetname);
if ccaON
   figure(1);hold on;plotCMCcurve(cmc_cca,'r','',datasetname);
end
figure(1);hold on;plotCMCcurve(cmc_kcca,'b','',datasetname);
if ccaON
   legend('Nearest Neighbour (NN)','Canonical Correlation Analysis (CCA)','Our approach (KCCA)');
else
   legend('Nearest Neighbour (NN)','Our approach (KCCA)');
end