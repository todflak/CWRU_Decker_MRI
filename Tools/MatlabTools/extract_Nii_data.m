Output_TallSkinny = true;
OutputFormatted = true;
Create_mean = true;

[filenames, status] = spm_select([1 Inf],'any','Select Nii image file(s)','',pwd,'\.nii(\.gz)?$');

if (size(filenames,1)>0)
    [dir, nam, ext, num] = spm_fileparts(filenames(1,:));
    output_dir = spm_select(1,'dir','Select output directory','',dir);
    output_filename = [nam '_data.txt'];
    output_filename = spm_input('Specify Output filename',1,'s', output_filename);
%     if (Create_mean)
%         output_filename_mean = [nam '_data_mean.txt'];
%         output_filename_mean = spm_input('Specify Output filename for MEAN',1,'s', output_filename_mean);
%     end
    for i=1:size(filenames,1)
        input_file =  filenames(1,:);
        [dir, nam, ext, num] = spm_fileparts(input_file);
        original_was_gzip =false;
        
        if strcmpi(ext,'.gz')
            original_was_gzip = true;
            input_file = gunzip(input_file);
            input_file = input_file{1}; %convert from cell array to char array
        end
        
        vol = spm_vol(input_file(1,:));
        data = spm_read_vols(vol);
        
        output_fullname = fullfile(output_dir, output_filename);
        if (size(filenames,1)>1)
            [dir, nam, ext, num] = spm_fileparts(output_fullname);
            output_fullname = fullfile(dir, [nam '_' num2str(i) '.' ext]);
        end
        
        if (OutputFormatted)
            lin_index = (1:length(data(:)))';  %generate all the linear index numbers (as a 1-column array)
            [I,J,K,N] = ind2sub(size(data),lin_index); %convert linear index to 4-dim coordinates 
            if (Output_TallSkinny)
                
                if (Create_mean) 
                   data_mean = mean(data,4); %average to eliminate 4-th dimension
                   data_mean = repmat(data_mean(:),size(data,4),1); %linearize mean matrix, and repeat to match number of 4-th dimension
                end
                
                data = data(:);  %linearize data matix
                
                %put all together
                T_data_all = table(I,J,K,N,data,data_mean);
                writetable(T_data_all,output_fullname);
            end
            
        end
        
        
        
        
        if original_was_gzip
            delete(input_file);
        end
    end
    
end;
%
% vol_info=dicomread(filenames);
% vol_data = spm_read_vols(vol_info);
%
