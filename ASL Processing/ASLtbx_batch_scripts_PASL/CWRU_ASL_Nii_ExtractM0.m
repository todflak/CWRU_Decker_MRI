% Extracts the M0 image from the rest of the PASL images; creates a new
% M0.nii and PASL.nii
% Modified from ASLtbx by Tod Flak 29 July 2017

%imgfiles should be a char vector.  For a single file, you can use syntax
%like ['C:\path\filename.nii']; for multiple files, use the char function,
%such as char('C:\path\filename_1.nii', 'C:\path\filename_2.nii')
%If imgfiles is empty will use the spm_select function

function CWRU_ASL_Nii_ExtractM0(imgfiles) 
   if ~exist('imgfiles','var') || isempty(imgfiles)
      imgfiles = spm_select;
   end

   for i = 1:size(imgfiles,1)
      nii_input_filename = imgfiles(i,:);
      fprintf('Processing NII file: %s \n', nii_input_filename);
      
      delete_uncompressed_Nii=false;
      nii_filename_toprocess = nii_input_filename;
      [pth,nam,ext,num] = spm_fileparts(nii_input_filename);
      if (strcmp(lower(ext),'.gz'))
         delete_uncompressed_Nii=true;
         nii_filename_toprocess = gunzip(nii_input_filename);
         nii_filename_toprocess = nii_filename_toprocess{1};
      end
      
      hdrs=spm_vol(nii_filename_toprocess);
      if ((rem(size(hdrs,1),2)==0) || (size(hdrs,1)<3) )
          fprintf('The NII should have an odd number of images, and be >=3; for image file %i, selected file contains %i images \n', i, size(hdrs,1) );
          return;
      end

      dat=spm_read_vols(hdrs(1));
      hdrs(1).fname=fullfile(spm_str_manip(nii_filename_toprocess, 'h'), 'M0.nii');
      hdrs(1)=spm_write_vol(hdrs(1), dat);
      % hdr=spm_vol(imgfiles(2:end,:));

      file4Dname=fullfile(spm_str_manip(nii_filename_toprocess, 'h'), 'PASL.nii');

      img_idx= 2:(size(hdrs,1)); %get the image indexes from 2 to end
      spm_file_merge(hdrs(img_idx),file4Dname,0);
      
      if (delete_uncompressed_Nii) 
         delete(nii_filename_toprocess)
      end       
      fprintf('Produced M0.nii and PASL.nii from input file: "%s"\n', nii_input_filename);

   end

end
