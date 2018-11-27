%CWRU_RejectOutlierImages(PAR, fidLog, Filter_MADThreshold, RemoveFirstPair)
%Tod Flak 05 June 2018
%
%Looks for images in the ASL sequence that are vrery different than the
%mean ASL, and removes them from the rPASL.nii
%
% Assumes there is existing files: rPASL.nii (realigned PASL images) (or
% other name, based on PAR selection)
% Copy the source file to name like rPASL_BeforeOutlierExclusion.nii
% First computes the mean of all PASL images
% For each image, computes the RMS of the delta (voxel_val - mean_voxel_val)
% Compute the MAD-fold  of RMS_delta from the median RMS_delta:
%   ([RMS delta] - Median([RMS delta])) / MedianAbsoluteDeviation([RMS delta])
% Determine which images have MAD-fold that is above Filter_MADThreshold
% Determine the *image pairs* that have one or more outlier image
% If RemoveFirstPair is true, always mark the first image pair as being
% outliers
% Recreate the original file, omitting the image pairs that are outliers
% Record into the log file the list of image numbers that were excluded

function CWRU_RejectOutlierImages(PAR, fidLog, ImageOutlierFiler_MADThreshold, RemoveFirstPair)
    if (exist('fidLog','var')==0) || (isempty(fidLog))
        fidLog = 1;
    end
    if (exist('ImageOutlierFiler_MADThreshold','var')==0) || (isempty(ImageOutlierFiler_MADThreshold))
        ImageOutlierFiler_MADThreshold = 6;
    end
    if (exist('RemoveFirstPair','var')==0) || (isempty(RemoveFirstPair))
        RemoveFirstPair = true;
    end

    if (fidLog<=0), fidLog=1; end  %if fidLog is not previously defined, set to 1 to send output to screen
    fprintf(fidLog,'\n%s: Remove outlier images, ImageOutlierFiler_MADThreshold=%f, RemoveFirstPair=%i\n', datestr(datetime('now')), ImageOutlierFiler_MADThreshold,RemoveFirstPair );

    for s = 1:PAR.nsubs % for each subject
        for c=1:PAR.ncond
            str   = sprintf('-- processing subject/condition: #%d/%d  (''%s''/''%s'')',s, c,PAR.subjects{s},PAR.sessionfilters{c} );
            fprintf(fidLog, '%s\n',str);
            rimgs=spm_select('EXTFPList', char(PAR.condirs{s,c}), ['^r' PAR.confilters{c} '.*nii'], 1:1000);
            [dir, nam, ext, ~] = spm_fileparts(rimgs(1,:));
            input_file = fullfile(dir,[nam  ext]);
            output_file = fullfile(dir,['oe_' nam  ext]);  %'oe' stands for outlier-excluded

            if (exist(output_file, 'file') ==2)
                % if there is already an 'oe' file, delete it
                delete(output_file);
            end

            %get the 4-D data
            vols = spm_vol(input_file);
            data = spm_read_vols(vols);
            data_mean = mean(data,4); %average to eliminate 4-th dimension
            series_count = size(data,4);

            %compute the RMS of the voxel-wise delta for each image
            rms_delta = zeros(series_count,1);
            for i=1:series_count
                delta = data(:,:,:,i) - data_mean;
                delta = delta(:); %convert to a single dimension
                rms_delta(i) = sqrt(mean(delta.^2));
            end

            % Compute the MAD-fold  of RMS_delta from the median RMS_delta:
            %   ([RMS delta] - Median([RMS delta])) / MedianAbsoluteDeviation([RMS delta])
            mad_fold = zeros(series_count,1);
            exclude_img = false(series_count,1);
            mad_all = mad(rms_delta,1); %compute the median absolute deviation of all rms_deltas
            median_rms_delta = median(rms_delta);
            for i=1:series_count
                mad_fold(i) = (rms_delta(i) - median_rms_delta)/mad_all;
                % Determine which images have MAD-fold that is above Filter_MADThreshold
                if (ImageOutlierFiler_MADThreshold>0) 
                    exclude_img(i) = (mad_fold(i)>=ImageOutlierFiler_MADThreshold);
                end
            end

            % Determine the *image pairs* that have one or more outlier image
            for idx_pair_0=0:(series_count/2 - 1)
                if (exclude_img(idx_pair_0*2 + 1) || exclude_img(idx_pair_0*2 + 2))
                    % if either of the pair is excluded, set both to
                    % excluded
                    exclude_img(idx_pair_0*2 + 1) = true;
                    exclude_img(idx_pair_0*2 + 2) = true;
                end
            end

            if (RemoveFirstPair)
                exclude_img(1) = true;
                exclude_img(2) = true;
            end

            include_img = ~exclude_img;
            count_included = size(include_img(include_img==true),1);

            %create a list of the images to include
            strImagesIdxExcluded = '';
            for i=1:series_count        
                if exclude_img(i)
                    strImagesIdxExcluded = [strImagesIdxExcluded ',' sprintf('%i',i)]; %#ok<AGROW>
                end
            end
            
            %also we need to edit the 'rp_PASL.txt' to delete the rows that
            %are for the excluded images
            movefil = spm_select('FPList', dir, ['^rp_' PAR.confilters{c} '.txt$']);
            [dir, nam, ext, ~] = spm_fileparts(movefil(1,:));
            input_move_file = fullfile(dir,[nam  ext]);
            output_move_file = fullfile(dir,['oe_' nam  ext]);  %'oe' stands for outlier-excluded
            moves = spm_load(input_move_file);            
            for i=series_count:-1:1   %do in reverse order to avoid hassle if changing indexes        
                if exclude_img(i)
                    moves(i,:)=[];  % delete this row
                end
            end
            
            %write the new file
            spm_file_merge(vols(include_img),output_file,0);
            %write the new movement file
            dlmwrite(output_move_file,moves,'delimiter','\t','precision','%.7e');
            
            
            fprintf(fidLog,'   Outlier images excluded: %s\n', strImagesIdxExcluded(2:end));
            fprintf(fidLog,'   Count image pairs remaining: %i\n',count_included /2);
            fprintf(fidLog,'   Outlier-excluded ASL sequence file created: %s\n', output_file);
        end
    end
end
