dicomfiles=spm_select;
hdr=spm_dicom_headers(dicomfiles);
[pth nam ext num] = spm_fileparts(hdr{1,1}.Filename);
cd(pth);
outdir= fullfile(pth, '..', 'Nii');
CWRU_spm_dicom_convert(hdr, 'all', 'series', 'nii', outdir, true, 24) ;
