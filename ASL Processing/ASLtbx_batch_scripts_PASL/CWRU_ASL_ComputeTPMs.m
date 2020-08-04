%  The goal of this function is to produce segmentation maps for grey
%  matter, white matter, CSF.
%  The strategy is to use SPM segmentation to warp the standard
%  TPMs (tissue probability maps) to match the structural image.
%  Tod Flak 28 Aug 2017


function CWRU_ASL_ComputeTPMs(Data_Root, Study_Folders_ToProcess, LogFilename, ...
                  StructuralImageNameSuffix)
   global PAR fidLog;
   OpenedLogFile = false;
   if exist('LogFilename','var') && (~isempty(LogFilename))
      fidLog = fopen(LogFilename, 'a');  %open for append
      OpenedLogFile = true;
   end
   
   if (exist('fidLog','var')==0) || isempty(fidLog)
      fidLog=1;  %default to standard out
   end
   
   if isempty(PAR)
      %set the parameters
      PAR = par(Data_Root, Study_Folders_ToProcess);      
   end
   
   if exist('StructuralImageNameSuffix','var')==0 || isempty(StructuralImageNameSuffix)
      %StructuralImageNameSuffix = '_norot';
      StructuralImageNameSuffix = '';
   end
   % if exist('ImageToSummarizeFilename','var')==0 || isempty(ImageToSummarizeFilename)
   %    ImageToSummarizeFilename = 'meanCBF_0_sASLflt_rASL.nii';
   % end
   % if exist('MaskForSummarizeFilename','var')==0 || isempty(MaskForSummarizeFilename)
   %    MaskForSummarizeFilename = 'brainmask\.nii';
   % end
   % if exist('OutputFileRootName','var')==0 || isempty(OutputFileRootName)
   %    OutputFileRootName = 'data';
   % end

   fprintf(fidLog,'%s: CWRU_ASL_ComputeTPMs, starting processing.\n', datestr(datetime('now')));
   fprintf(fidLog,'Data_Root:%s.\n', Data_Root);
   fprintf(fidLog,'Study_Folders_ToProcess:\n%s\n', char(Study_Folders_ToProcess));

   fprintf(fidLog,'\n%s: Normalize to TPM tissue segmentation model.\n', datestr(datetime('now')));
   %   fprintf(fidLog,'StructuralImageFilename: %s\n', StructuralImageFilename);
   %   fprintf(fidLog,'ImageToSummarizeFilename: %s\n', ImageToSummarizeFilename);
   %   fprintf(fidLog,'LogFilename: %s\n', LogFilename);




   for s = 1:PAR.nsubs
      [pth,nam,ext,num] = spm_fileparts(PAR.structname{s});
      StructuralImageToSegment = fullfile(pth, [nam StructuralImageNameSuffix ext num]);
      str = sprintf('%s: For subject #%d (''%s''), performing segmentation for structural image: %s\n',  ...
         datestr(datetime('now')),  s, PAR.subjects{s},  StructuralImageToSegment);
      fprintf(fidLog, '%s\n',str);

      clear matlabbatch;

      nrun = 1; % enter the number of runs here
      [CodePath,nam,ext,num] = spm_fileparts(mfilename('fullpath')); %#ok<ASGLU>
      jobfile = {[CodePath '\CWRU_ASL_SimpleSegmentation_segmentjob.m']};
      jobs = repmat(jobfile, 1, nrun);
      inputs = cell(7, nrun);
      for crun = 1:nrun
         inputs{1, crun} = {StructuralImageToSegment}; % Segment: Volumes
         TPM_Filename = [spm('Dir') '\tpm\TPM.nii'];
         inputs{2, crun} = {[TPM_Filename ',1']}; % Segment: Tissue probability map part 1 - Grey matter
         inputs{3, crun} = {[TPM_Filename ',2']}; % Segment: Tissue probability map part 2 - White matter
         inputs{4, crun} = {[TPM_Filename ',3']}; % Segment: Tissue probability map part 3 - CSF
         inputs{5, crun} = {[TPM_Filename ',4']}; % Segment: Tissue probability map part 4 - Bone
         inputs{6, crun} = {[TPM_Filename ',5']}; % Segment: Tissue probability map part 5 - Soft tissue
         inputs{7, crun} = {[TPM_Filename ',6']}; % Segment: Tissue probability map part 6 - background space
      end
      spm('defaults', 'FMRI');
      spm_jobman('run', jobs, inputs{:});

      fprintf(fidLog,'%s: For subject #%d (''%s''), completed segmentation, produced the class images for tissues 1-6 \n',  ...
         datestr(datetime('now')),  s, PAR.subjects{s});

   %    %Now apply these class probability images to the ASL CBF data
   %    [pth,nam,ext,num] = spm_fileparts(StructuralImageToSegment);
   %    
   %    for c=1:PAR.ncond
   %       str   = sprintf('-- processing subject/condition: #%d/%d  (''%s''/''%s'')',s, c,PAR.subjects{s},PAR.sessionfilters{c} );
   %       fprintf(fidLog, '%s\n',str);
   %       
   %       ASL_DataToSummarize_Filename = fullfile(PAR.condirs{c}, [ImageToSummarizeFilename num]);
   %       ASL_MaskForDataToSummarize_Filename =  fullfile(PAR.condirs{c}, [MaskForSummarizeFilename num]);
   % 
   %       for i=1:3
   %          TissueClass_TPM_Filename = fullfile(pth, ['c' char(sprintf('%d',i)) nam ext num]);
   %          switch i
   %             case 1
   %                TissueTypeAbbrev = 'GM';
   %                TissueTypeName = 'grey matter';
   %             case 2
   %                TissueTypeAbbrev = 'WM';
   %                TissueTypeName = 'white matter';
   %             case 3
   %                TissueTypeAbbrev = 'CSF';
   %                TissueTypeName = 'CSF';
   %             otherwise
   %                TissueTypeAbbrev = 'NA';
   %                TissueTypeName = 'not configured';
   %          end
   %          
   %          OutputFilename = [TissueTypeAbbrev '_' OutputFileRootName ext ];
   %      
   %          nrun = 1; % enter the number of runs here
   %          jobfile = {[CodePath '\CWRU_ASL_SimpleSegmentation_calcjob.m']};
   %          jobs = repmat(jobfile, 1, nrun);
   %          inputs = cell(3, nrun);
   %          for crun = 1:nrun
   %             inputs{1, crun} = cellstr(char(ASL_DataToSummarize_Filename, TissueClass_TPM_Filename)) ; % Image Calculator: Input Images - cfg_files
   %             inputs{2, crun} = OutputFilename; % Image Calculator: Output Filename - cfg_entry
   %             inputs{3, crun} = cellstr(PAR.condirs{c}); % Image Calculator: Output Directory - cfg_files
   %          end
   %          spm('defaults', 'FMRI');
   %          spm_jobman('run', jobs, inputs{:});
   %          
   %          OutputFileFullName = fullfile(PAR.condirs{c}, OutputFilename);
   %          fprintf(fidLog,'   For subject/condition: #%d/%d  (''%s''/''%s''), tissue ''%s'' produced tissue class image: %s\n', ... 
   %                                  s, c,PAR.subjects{s},PAR.sessionfilters{c},TissueTypeName, OutputFileFullName );

   %          %now we can summarize the data to produce a mean and stdev for the
   %          %entire tissue
   %          niiTPM = load_untouch_nii(TissueClass_TPM_Filename);
   %          niiMask = load_untouch_nii(ASL_MaskForDataToSummarize_Filename);
   %          niiData = load_untouch_nii(OutputFileFullName);
   %          voxelsize_mm3 = prod(niiData.hdr.dime.pixdim(2:4));
   %          arrLabel_ThisID = (niiTPM.img>0); 
   %          vecDataElements = niiData.img((niiTPM.img>0) & (niiMask.img>0.5)); %pull out a vector of data 
   %          % where the find cells in the TPM image matrix that are greater than zero... these are the 
   %          % voxels where some of this tissue may be located.
   %          % Also, apply the condition that the mask should be greater than
   %          % 0.5, because only in those locations is the data valid (by
   %          % default, you might think we should use where niiMask.img>0, but
   %          % due to the resampling when we increased the resolution to match
   %          % the anatomical image, we should set the threshold at 0.5.  
   %          % TF 05 Oct 2017
   %            
   %          %assemble all the data we need to add a row to the output table
   %          Mean = mean(vecDataElements);
   %          Mean_StDev = std(vecDataElements);
   %          Count_Voxels = size(vecDataElements,1);
   %          Volume_mm3 = Count_Voxels * voxelsize_mm3;
   %          
   %          fprintf(fidLog,'   For subject/condition: #%d/%d  (''%s''/''%s''), tissue ''%s'', determined: Volume(mm^3): %f, %s Mean: %f, StDev: %f\n', ... 
   %                                       s, c,PAR.subjects{s},PAR.sessionfilters{c},TissueTypeName, Volume_mm3, OutputFileRootName, Mean, Mean_StDev);
   %          
   %       end
   %    end
   end

   fprintf(fidLog,'%s: CWRU_ASL_ComputeTPMs, completed processing.\n', datestr(datetime('now')));
   if (fidLog>1 && OpenedLogFile) , fclose(fidLog); end
   clear matlabbatch 

end