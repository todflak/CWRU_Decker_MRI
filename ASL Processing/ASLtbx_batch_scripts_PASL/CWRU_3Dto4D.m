% use the following code to convert 3D images to 4D images
imgfiles=spm_select;
v=spm_vol(imgfiles(1:end,:));
file4Dname=fullfile(spm_str_manip(imgfiles(1,:), 'h'), ['All_ASL.nii']);
spm_file_merge(v,file4Dname,0);
% delete the original 3D files
for i=1:size(imgfiles,1)
    delete(imgfiles(i,:));
end