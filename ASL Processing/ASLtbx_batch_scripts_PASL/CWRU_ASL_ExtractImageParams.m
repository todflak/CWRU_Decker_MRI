% Extracts the image parameters from the given Nii file.
% Values extracted include: Xdim, Ydim, Zdim, 
% Modified from ASLtbx by Tod Flak 29 July 2017

%imgfiles should be a char vector.  For a single file, you can use syntax
%like ['C:\path\filename.nii']; for multiple files, use the char function,
%such as char('C:\path\filename_1.nii', 'C:\path\filename_2.nii')
%If imgfiles is empty will use the spm_select function

function CWRU_ASL_ExtractImageParams(imgfiles) 
   if ~exist('imgfiles','var') || isempty(imgfiles)
      imgfiles = spm_select;
   end

   for i = 1:size(imgfiles,1)
      nii_input_filename = imgfiles(i,:);
      fprintf('Params for NII file: %s \n', nii_input_filename);
      %v=spm_vol(imgfiles(i,:));  
%       fprintf('  CountImages=%d\n', length(v));
%       fprintf('  Xdim=%d\n', v(1).dim(1));
%       fprintf('  Ydim=%d\n', v(1).dim(2));
%       fprintf('  Zdim=%d\n', v(1).dim(3));
      [header,~,~,~]= load_untouch_header_only(imgfiles(i,:));
      fprintf('  CountImages=%d\n', header.dime.dim(5));
      fprintf('  Xdim=%d\n', header.dime.dim(2));
      fprintf('  Ydim=%d\n', header.dime.dim(3));
      fprintf('  Zdim=%d\n', header.dime.dim(4));
      fprintf('  Xsize=%d\n', header.dime.pixdim(2));
      fprintf('  Ysize=%d\n', header.dime.pixdim(3));
      fprintf('  Zsize=%d\n', header.dime.pixdim(4));
      fprintf('------\n');
   end

end
