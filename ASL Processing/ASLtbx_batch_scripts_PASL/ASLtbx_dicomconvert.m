dicomfiles=spm_select;
hdr=spm_dicom_headers(dicomfiles);
[pth nam ext num] = spm_fileparts(hdr{1,1}.Filename);
cd(pth);
cd('..\Nii');
spm_dicom_convert(hdr, 'all', 'series', 'nii') ;
