%This is a wrapper function around the original ASLtbx toolbox script
%"batch_run".  Note that we have commented out the call to
%batch_reset_orientation, so images are not reset... we keep in the same
%orientation to allow easier eventual registration with the SVREg
%segmentation labels.
% Tod Flak 22 Aug 2017

%Data_Root (char vector) must be path to data folder inside of which are
%session folders.

%Study_Folders_ToProcess should be a array of char vector.  For a single
% session folder, you can use syntax %like ['subject1']; for multiple
% folders, use the char function, such as char('subject1', 'subject2')
%If Study_Folders_ToProcess is empty will use the spm_select function
%If LogFilename (char vector) is not specified, output will go to screen.
%ASL_Quant_Params is a vector of values to assign these parameters:
%  [Labeltime_ms Delaytime_ms  Slicetime_ms TE_ms Labeling_Efficiency SubtractionOrder]
% for example:
%  [700 1800 53 17 0.90 1]
% If not specified, it has those values.
%An example call:
% CWRU_ASL_Compute_CBF('C:\Users\Tod\Documents\BioAutomatix\Clients\Decker\MRI Processing\Example data\WPAFB', ['20170801'], 'C:\Users\Tod\Documents\BioAutomatix\Clients\Decker\MRI Processing\Example data\WPAFB\20170801\ASL\BasicASLAnalysis_Log.txt')

function CWRU_ASL_Compute_CBF(Data_Root, Study_Folders_ToProcess, LogFilename, ...
         ASL_Quant_Params, SpecificStepToRun, OutlierMode, ASL_Type, PrecomputedCBF_Scaling, ImageOutlierFiler_MADThreshold )

   % Batch mode scripts for running spm2 in TRC
   % Created by Ze Wang, 08-05-2004
   % zewang@mail.med.upenn.edu
   % use the following code to prepare the data
   % first convert DICOM into nifti
   % ASLtbx_dicomconvert;
   % ASLtbx_3Dto4D;
   %example code for processing PASL data
   clear global PAR
   clear global fidLog
   
   global PAR fidLog
   fidLog=1;  %default to standard out
   PAR=[];
   
   try

      if exist('LogFilename','var') && (~isempty(LogFilename))
         fidLog = fopen(LogFilename, 'a');  %open for append
      end
      if (exist('SpecificStepToRun','var')==0) || (isempty(SpecificStepToRun))
         SpecificStepToRun = 'All';
      end
      
      if (exist('OutlierMode','var')==0) || (isempty(OutlierMode))
         OutlierMode = 1;
      end    
      
      if (exist('ASL_Type','var')==0) || (isempty(ASL_Type))
	     ASL_Type = 0;
	  end 	  

      if (exist('PrecomputedCBF_Scaling','var')==0) || (isempty(PrecomputedCBF_Scaling))
	     PrecomputedCBF_Scaling = 1;
      end 	
      
      if (exist('ImageOutlierFiler_MADThreshold','var')==0) || (isempty(ImageOutlierFiler_MADThreshold))
	     ImageOutlierFiler_MADThreshold = 6;
      end 	  
       
      fprintf(fidLog,'%s: CWRU_ASL_Compute_CBF, starting processing.\n', datestr(datetime('now')));
      fprintf(fidLog,'Data_Root:%s.\n', Data_Root);
      fprintf(fidLog,'Study_Folders_ToProcess:\n%s\n', char(Study_Folders_ToProcess));
      
      %set the parameters
      par(Data_Root, Study_Folders_ToProcess);

         PAR.ASL_Quant_Params = ASL_Quant_Params;
      if (exist('ASL_Quant_Params','var')==0) || (isempty(ASL_Quant_Params))
         PAR.ASL_Quant_Params = [700 1800 53 17 0.90 1];
      else
      end
     
	  DoSmoothing = isempty(strfind(lower(SpecificStepToRun),'nosmoothing'));
      
      % set the center to the center of each images
      % batch_reset_orientation;

      
      switch SpecificStepToRun
         case {'All', 'Basic', 'All_SimpleCBF', 'Basic_TPM', 'Basic_NoSmoothing'}
            %motion correction-- realign the functional images to the first functional image of each subject
            CWRU_batch_realign_unwarp;   %TF 11 Nov 2019; was batch_realign; 
            CWRU_RejectOutlierImages(PAR,fidLog, ImageOutlierFiler_MADThreshold, true, 0.3);
%            CWRU_RejectOutlierImages(PAR,fidLog, 100, false, 100);  %this put in 29Jun2020 solely for pCASL to avoid removing any images
            
            % register M0 to the mean BOLD generated during motion correction for the raw ASL images
            batch_coreg_M0; 

            %coreg the functional images to the anatomical image
            batch_coreg; 

            %filter and smooth the coreged functional images
            batch_brainmask; 

            %filter and smooth the coreged functional images
            batch_filtering; 
			
            batch_smooth(PAR, fidLog, DoSmoothing)
            
            if strcmp(SpecificStepToRun,'All')
               CWRU_ASL_ComputeTPMs(Data_Root, Study_Folders_ToProcess);
               CWRU_batch_perf_subtract_segmented(PAR, fidLog, OutlierMode, true, ASL_Type, PrecomputedCBF_Scaling);    

            elseif   strcmp(SpecificStepToRun,'All_SimpleCBF')
               CWRU_batch_perf_subtract_segmented(PAR, fidLog, OutlierMode, false, ASL_Type, PrecomputedCBF_Scaling);   

            elseif   strcmp(SpecificStepToRun,'Basic_TPM')
              CWRU_ASL_ComputeTPMs(Data_Root, Study_Folders_ToProcess);
            end
            
         case 'realign'
            CWRU_batch_realign_unwarp;  %TF 11 Nov 2019; was batch_realign; 
            CWRU_RejectOutlierImages(PAR,fidLog, ImageOutlierFiler_MADThreshold, true)
            
         case 'coreg_M0'
            batch_coreg_M0; 
            
         case 'coreg'
            batch_coreg; 
            
         case 'brainmask'
           batch_brainmask;

         case 'filtering'
            batch_filtering; 
            
         case {'smooth', 'smooth_NoSmoothing'}
            batch_smooth(PAR, fidLog, DoSmoothing); 
         
         case 'perf_subtract_simple'    
            CWRU_batch_perf_subtract_segmented(PAR, fidLog, OutlierMode, false, ASL_Type, PrecomputedCBF_Scaling); 
            
         case 'perf_subtract_segmented'
            CWRU_batch_perf_subtract_segmented(PAR, fidLog, OutlierMode, true, ASL_Type, PrecomputedCBF_Scaling);    
            
         case 'TPM_Segment'
            CWRU_ASL_ComputeTPMs(Data_Root, Study_Folders_ToProcess);

         case 'Segment_and_perf_subtract_segmented'
            CWRU_ASL_ComputeTPMs(Data_Root, Study_Folders_ToProcess);
            CWRU_batch_perf_subtract_segmented(PAR, fidLog, OutlierMode, true, ASL_Type, PrecomputedCBF_Scaling);    

         otherwise
            fprintf(fidLog,'Argument Error -- unrecognized value for SpecificStepToRun: %s.\n', SpecificStepToRun);

      end      
% 
%       % normalizing mean CBF maps into MNI space
%       %NO LONGER PART OF THE STANDARD ANALYSIS, but can be run on demand by
%       %setting SpecificStepToRun
%       if strcmp(SpecificStepToRun,'batch_norm_spm12'),  batch_norm_spm12; end
      
      fprintf(fidLog,'\n%s: CWRU_ASL_Compute_CBF, processing complete.\n', datestr(datetime('now')));

   catch ex

      fprintf(fidLog,'\n\nProcessing Error: %s.\n', ex.message);
      fprintf(fidLog,'Stack trace:\n');
      for k=1:length(ex.stack)
         fprintf(fidLog,'% *d: %s, line %d\n', k+1, k, ex.stack(k).name, ex.stack(k).line);
      end
   end   
   
   
   if (fidLog>=3)
      fclose(fidLog);
   end
end
