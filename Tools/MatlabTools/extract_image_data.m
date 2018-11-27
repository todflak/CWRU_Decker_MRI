Output_TallSkinny = true;

[filenames, status] = spm_select([1 Inf],'any','Select IMA image file(s)','',pwd,'.IMA$');

if (size(filenames,1)>0)
   [dir, nam, ext, num] = spm_fileparts(filenames(1,:));
   output_dir = spm_select(1,'dir','Select output directory','',dir);
   output_filename = spm_input('Specify Output filename',1,'s');

   for i=1:size(filenames,1)
      info = dicominfo(filenames(i,:));
      data = dicomread(filenames(i,:));   
      
      if (info.Height~=info.AcquisitionMatrix(1) || info.Width~=info.AcquisitionMatrix(4))
         Slice_Height = info.AcquisitionMatrix(1);
         Slice_Width = info.AcquisitionMatrix(4);
         
         SliceCount = info.Private_0019_100a;  %not sure this will always work!

         data_slices = zeros(Slice_Height, Slice_Width, SliceCount);
         subplots_sqrt= ceil(sqrt(double(SliceCount)));
         
         for i = 1:SliceCount 
            %determine the row and column index of each subplot (0-based numbers)
            i_0 = double(i-1);
            slice_subplot_row_0 = floor(i_0/subplots_sqrt);
            slice_subplot_col_0 = mod(i_0,subplots_sqrt);

            subplot_TL_Y_0 = slice_subplot_row_0*Slice_Height;
            subplot_TL_X_0 = slice_subplot_col_0*Slice_Width;

            slice_data = data((subplot_TL_Y_0+1):(subplot_TL_Y_0+Slice_Height), (subplot_TL_X_0+1):(subplot_TL_X_0+Slice_Width));
            data_slices(:,:,i)=slice_data;
            
%             if (EliminateNegativeCBF_Values)
%                data_slices(:,:,i) = (slice_data-2048)./5;
%             else
%                data_slices(:,:,i) = (cast(slice_data,'single') -2048)./5; 
%             end;

         end;      
         data = data_slices;
      end;
      
      
      output_fullname = fullfile(output_dir, output_filename);
      if (size(filenames,1)>1) 
         [dir, nam, ext, num] = spm_fileparts(output_fullname);
         output_fullname = fullfile(dir, [nam '_' num2str(i) '.' ext]);
      end;
      
      if (Output_TallSkinny)
         data = data(:);
      end;
      
      csvwrite(output_fullname, data);
   end;
end;
% 
% vol_info=dicomread(filenames);
% vol_data = spm_read_vols(vol_info);
% 
