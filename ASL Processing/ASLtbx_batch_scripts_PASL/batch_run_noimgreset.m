
% Batch mode scripts for running spm2 in TRC
% Created by Ze Wang, 08-05-2004
% zewang@mail.med.upenn.edu
% use the following code to prepare the data
% first convert DICOM into nifti
% ASLtbx_dicomconvert;
% ASLtbx_3Dto4D;
%example code for processing PASL data

%set the parameters
global PAR
par;

% set the center to the center of each images

% batch_reset_orientation;


%realign the functional images to the first functional image of eachsubject
batch_realign;

% register M0 to the mean BOLD generated during motion correction for the
% raw ASL images
batch_coreg_M0;

%coreg the functional images to the anatomical image
batch_coreg;

batch_filtering;
%smooth the coreged functional images
batch_smooth;

batch_perf_subtract;

% normalizing mean CBF maps into MNI space
batch_norm_spm12;