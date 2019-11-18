%CWRU_RejectOutlierImages(PAR, fidLog, Filter_MADThreshold, RemoveFirstPair, PairwiseMotionCorrectLimit)
%Tod Flak 05 June 2018
%
%Looks for images in the ASL sequence that are very different than the
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

% TF 13 Nov 2019: Added option to also exclude image pairs based upon the
% differential motion of the images in each pair.  The idea here is that we
% are really most interesting in avoiding image pairs where they were far
% apart in the original uncorrected data.  Even if the images both got
% motion-corrected to be well super-imposed, the problem can be that they 
% experienced different distortions.  To evaluate this, compare the
% motion correction that was performed on the images BY PAIR -- if the
% motion correction is very different between the two images of the pair,
% reject that pair.  This option is controlled by parameter
% 'PairwiseMotionCorrectLimit' -- omit or set to 0 will skip this test; a
% positive value will reject the pair if the relative motion correction is
% above this limit.  Note that the angular motion correction values are
% converted to distance considering a radius of 0.4 of the image size.

function CWRU_RejectOutlierImages(PAR, fidLog, ImageOutlierFiler_MADThreshold, RemoveFirstPair, PairwiseMotionCorrectLimit)
    if (exist('fidLog','var')==0) || (isempty(fidLog))
        fidLog = 1;
    end
    if (exist('ImageOutlierFiler_MADThreshold','var')==0) || (isempty(ImageOutlierFiler_MADThreshold))
        ImageOutlierFiler_MADThreshold = 6;
    end
    if (exist('RemoveFirstPair','var')==0) || (isempty(RemoveFirstPair))
        RemoveFirstPair = true;
    end
    if (exist('PairwiseMotionCorrectLimit','var')==0) || (isempty(PairwiseMotionCorrectLimit))
        PairwiseMotionCorrectLimit = 0;
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
            exclude_img_byMAD = false(series_count,1);
            exclude_img_byPairwiseMotionCorrectLimit = false(series_count,1);
            mad_all = mad(rms_delta,1); %compute the median absolute deviation of all rms_deltas
            median_rms_delta = median(rms_delta);
            for i=1:series_count
                mad_fold(i) = (rms_delta(i) - median_rms_delta)/mad_all;
                % Determine which images have MAD-fold that is above Filter_MADThreshold
                if (ImageOutlierFiler_MADThreshold>0) 
                    exclude_img(i) = (mad_fold(i)>=ImageOutlierFiler_MADThreshold);
                    if  exclude_img(i)
                        exclude_img_byMAD(i) = true;
                    end
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

            %this added 13 Nov 2019, TF 
            if (PairwiseMotionCorrectLimit>0)
                % getting the motion correction results. Assuming it is located in the same folder as the images
                movefil = spm_select('FPList', dir, ['^rp_.*\w*.*\.txt$']);
                moves = spm_load(movefil);
                if (size(moves,2)>6)  %for explanation about this condition,
                    %see note in ASLtbx_asltemporalfiltering.m
                    moves = moves(:,7:12);
                end
                %Now moves has the realignment info for each image in the
                %series; column 1,2,3 are the X,Y,Z moveements; and
                %columns 4,5,6 are the pitch, roll, yaw (I am not
                %absolutely certain about that order, but I've seen it
                %written in that order on some tutorial web pages) -- so
                %they would be rotations around the X, Y, and Z axes
                %respectively.
               
                %To make estimates of effects of angular rotations around the 
                % origin, presume that the origin is basically in the
                % center of the brain (more or less true).  Imagine a point 
                % that is 40% of the image size away from the center in each 
                % dimension.  So, for an ASL image that has voxel size of 
                % [3.475, 3.475, 10]mm and image dimensions of [64,64,27],
                % the point we would think about would be at voxel location
                % V= 0.4 * [32, 32, 13.5]; or at physical location of 
                % P = V .* [3.475, 3.475, 10]mm = [88.0000   88.0000   54.0000] 
               
                % So, get image sizes
                [header, ext, filetype, machine] = load_untouch_header_only(input_file);
                    %header.dime.pixdim : [-1, 3.475, 3.475, 5, 0, 0 ,..]
                    %header.dime.dim: [4,64,64,27,90,1,1,1]
                test_point =  [(header.dime.dim(2:4)*0.4).* header.dime.pixdim(2:4) 1];
                %Note --add a 1 as fourth element to allow translations
                
                %Now for each image, apply the transformations to that
                %testpoint
                N_img = header.dime.dim(5);
                test_point_moved = zeros(N_img, 4);
                for i=1:N_img
                    q= quaternion.eulerangles('xyz',deg2rad(moves(i,4:6)));
                    M = zeros(4,4);  %create an 3D affine transformation matrix
                    M(1:3,1:3) = q.RotationMatrix;  %upper left 3x3 is rotation matrix
                    M(4,1:3) = moves(i,1:3); %row 4 is for translations
                    M(4,4) = 1;
                    test_point_moved(i,:) = test_point * M;
                end
                
                %now compute the distance between the test points for each
                %image pair; if greater than threshold, mark pair for
                %exclusion
                d_e = zeros(N_img/2,2);
                for ip=1:(N_img/2)
                    i = (ip-1)*2+1;
                    distance = norm(test_point_moved(i,1:3) - test_point_moved(i+1,1:3));
                    d_e(ip,1)=distance;
                    if (distance>PairwiseMotionCorrectLimit)
                        d_e(ip,2)=1;
                        exclude_img(i) = true;
                        exclude_img(i+1) = true;
                        exclude_img_byPairwiseMotionCorrectLimit(i) = true;
                        exclude_img_byPairwiseMotionCorrectLimit(i+1) = true;
                    end
                end
            end
            
            include_img = ~exclude_img;
            count_included = size(include_img(include_img==true),1);

            %create a list of the images to include
            strImagesIdxExcluded = '';
            strImagesIdxExcluded_byMAD = '';            
            strImagesIdxExcluded_byPairwiseMotionCorrectLimit = '';
            for i=1:series_count        
                if exclude_img(i)
                    strImagesIdxExcluded = [strImagesIdxExcluded ',' sprintf('%i',i)]; %#ok<AGROW>
                end
                if exclude_img_byMAD(i)
                    strImagesIdxExcluded_byMAD = [strImagesIdxExcluded_byMAD ',' sprintf('%i',i)]; %#ok<AGROW>
                end
                if exclude_img_byPairwiseMotionCorrectLimit(i)
                    strImagesIdxExcluded_byPairwiseMotionCorrectLimit = [strImagesIdxExcluded_byPairwiseMotionCorrectLimit ',' sprintf('%i',i)]; %#ok<AGROW>
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
            fprintf(fidLog,'   Outlier images excluded by MAD filter: %s\n', strImagesIdxExcluded_byMAD(2:end));
            fprintf(fidLog,'   Outlier images excluded by PairwiseMotionCorrectLimit: %s\n', strImagesIdxExcluded_byPairwiseMotionCorrectLimit(2:end));
            fprintf(fidLog,'   Count image pairs remaining: %i\n',count_included /2);
            fprintf(fidLog,'   Outlier-excluded ASL sequence file created: %s\n', output_file);
        end
    end
end
