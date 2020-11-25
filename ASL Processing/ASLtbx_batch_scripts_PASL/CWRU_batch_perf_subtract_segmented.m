% Toolbox for batch processing ASL perfusion based fMRI data.
% All rights reserved.
% Ze Wang @ TRC, CFN, Upenn 2004
%
% Batch calculation for the perfusion signals, using TPM segmented maps.

function CWRU_batch_perf_subtract_segmented(PAR, fidLog, OutlierMode, SegmentByTPM, ...
               ASL_Type, PrecomputedCBF_Scaling)

   %global PAR fidLog;
   if (exist('fidLog','var')==0) || (isempty(fidLog))
      fidLog = 1;
   end      
   if (exist('OutlierMode','var')==0) || (isempty(OutlierMode))
      OutlierMode = 1;
   end      
   if (exist('SegmentByTPM','var')==0) || (isempty(OutlierMode))
      SegmentByTPM = false;
   end 
   if (exist('ASL_Type','var')==0) || (isempty(ASL_Type))
      ASL_Type = 0;
   end 
   if (exist('PrecomputedCBF_Scaling','var')==0) || (isempty(PrecomputedCBF_Scaling))
      PrecomputedCBF_Scaling = 1;
   end    
   
   if (fidLog<=0), fidLog=1; end  %if fidLog is not previously defined, set to 1 to send output to screen
   fprintf(fidLog,'\n%s: Calculate perfusion and CBF signals, using TPMs, OutlierMode=%i\n', datestr(datetime('now')), OutlierMode);

   % PAR.ASL_Quant_Params must be a vector of values to assign these parameters:
   %  [Labeltime_ms Delaytime_ms  Slicetime_ms TE_ms Labeling_Efficiency SubtractionOrder]


   for s = 1:PAR.nsubs % for each subject

      for c=1:PAR.ncond
         str   = sprintf('-- processing subject/condition: #%d/%d  (''%s''/''%s'')',s, c,PAR.subjects{s},PAR.sessionfilters{c} );
         fprintf(fidLog, '%s\n',str);


         %look for a file with special processing settings.  If found, read
         %into name value list.  TF 24 Nov 2020
         % I added this code to support some more advanced processing
         % options, such as changing the T1blood for diffent ASL images.
         % This processing settings file could easily be used to replace
         % other options, such as the OutlierMode stuff... really, all of
         % the special parameters that we are currently passing in on the
         % command line into this procedure could be placed in this  
         % processing settings file.  But I'm not going to do that now...
         % no strong motivation to revise stuff that is already working.
         % TF 24 Nov 2020
         processing_settings = struct([]) ;  %create empty structure
         processing_settings_filename = fullfile(PAR.condirs{s,c},'processing_settings.txt');   
         if isfile(processing_settings_filename)
            fid = fopen(processing_settings_filename);
            settingline = fgetl(fid);
            while ischar(settingline) %when reaches EOF, settingline will be a numeric type with value -1
                settingline_nocomment =  strsplit(settingline,'%');
                settingline_nocomment = strtrim(settingline_nocomment{1});
                if ~isempty(settingline_nocomment)
                    settings_parts = strsplit(settingline_nocomment,'=');
                    if size(settings_parts,2)<2  %if only one setting part (something like "Variable" )
                        settings_parts{1,2}='';  %set the second part to empty string
                    end
                    setting_this = struct('Name',strtrim(settings_parts{1,1}),'Value',strtrim(settings_parts{1,2}));
                    processing_settings = [processing_settings, setting_this]; 
                end
                settingline = fgetl(fid);
            end
            fclose(fid);            
         end
         
         %for input select the smoothed, ASL, filtered, outlier-excluded,
         %realigned PASL/PCASL nii file
         P =  spm_select('ExtFPList', PAR.condirs{s,c}, ['^sASLflt_oe_r'  PAR.confilters{c} '\.nii'], 1:1000 );

         if ((OutlierMode==9) | (OutlierMode==10) )
            %this is a special mode to implement the Chris Flask method of computation.
            %If we are on c=1 (first ASL of group), produce a modified maskfile.  This
            % assumes that you have already completed CBF computation using a different 
            % mode, and that the file 'meanCBF_0_sASLflt_rASL'
           if (c==1)
              fprintf(fidLog, 'Will produce filtered brain mask.\n');
              maskimg=spm_select('FPList', PAR.condirs{s,c}, ['^brainmask\.nii']);
              cbfimg = spm_select('FPList', PAR.condirs{s,c}, ['^meanCBF_0_sASLflt_rASL\.nii']);
              maskimg_filtered = fullfile( PAR.condirs{s,c}, 'brainmask_filtered.nii');
              switch (OutlierMode)
                case 9
                  filter_level = 15;
				    case 10
                  filter_level = 0;
			     end			  
              fprintf(fidLog, 'Will produce filtered brain mask, with CBF filter level=%f.\n', filter_level);
              CWRU_ASL_FilterMaskByCBF(maskimg,cbfimg,filter_level,maskimg_filtered, fidLog);
           end
           %NOTE for this filtered brainmask, always look in the ASL 1 folder
           maskimg=spm_select('FPList', PAR.condirs{s,1}, ['^brainmask_filtered\.nii']);
           
         else            
            maskimg=spm_select('FPList', PAR.condirs{s,c}, ['^brainmask\.nii']);
         end
         M0img =  spm_select('ExtFPList', PAR.condirs{s,c}, ['^srM0.*\.nii'], 1:1000 );
         PrecomputedCBF_File=[];

         % Corrected this next line .. there is no "sM0.nii" file, but there
         % is a "srM0.nii" (smoothed, co-registered).  TF 25 Aug 2017
   %      M0img =  spm_select('ExtFPList', PAR.condirs{s,c}, ['^sM0.*\.nii'],1:1000 );   
      


         % the asl_perf_subtract does not like the ",1" on end of the filename
         % returned by spm_select

         %       CWRU_perf_subtract(Filename,FirstimageType, SubtractionType,...
         %               SubtractionOrder,Flag,   ...
         %               Timeshift,AslType,labeff,MagType, ...
         %               Labeltime,Delaytime,Slicetime,TE,M0img,M0roi,maskimg, ...
         %               M0csf,M0wm,threshold, ...
         %               Foldername_TPMs)
         %
         % Flag vector:
         %    Flag - flag vector composed of [MaskFlag,MeanFlag,CBFFlag,BOLDFlag,OutPerfFlag,OutCBFFlag,QuantFlag,ImgFormatFlag,D4Flag,M0wmcsfFlag]
         %        1.  MaskFlag - integer variable indicating whether perfusion images are
         %               masked by BOLD image series, usually, it's masked to remove the
         %               background noise and those non-perfusion regions.
         %               - 0:no mask; 1:masked
         %
         %        2.  MeanFlag - integer variable indicating whether mean image of all perfusion images are produced
         %               - 0:no mean image; 1: produced mean image
         %        3.  CBFFlag - indicator for calculating cbf. 1: calculated, 0: no
         %        4.  BOLDFlag - generate pseudo BOLD images from the tag-utag pairs.
         %        5.  OutPerfFlag: write perf signal to disk or not? 1 yes, 0:no
         %        6.  OutCBFFlag: write CBF signal to disk or not?
         %        7.  QuantFlag: using a unique M0 value for the whole brain? 1:yes, 0:no.
         %        8.  ImgFormatFlag: 0 (default) means saving images in Analyze format, 1 means using NIFTI
         %        9.  D4Flag       : 0 (default) - no, 1 - yes
         %       10.  M0wmcsfFlag: 1 - using M0csf to estimate M0b, 0 - using M0wm to estimate M0b, -1 - disabled
         %       11.  OutliersNANFlag: 1: set outlier to NaN in the CBF 4D images
         %       12.  DumpCBF_DataFlag: 1 - save all CBF data (for each perfusion image pair) to text file 'CBF_Data.xlsx'
         %       13.  ExcludeOutliersEachPerfusion: 1 - (as implemented in original code) outliers are
         %                    eliminated in EACH perfusion image pair; 0 - outliers are eliminated from the
         %                    final averaged CBF map
         %       14.  OutlierThresholds_IsFixedValues: if 0, the OutlierThresholds represent the number of
         %                     sigmas away from mean to exclude; if 1, the OutlierThresholds represent fixed 
         %                     thresholds of CBF to exclude      

         % PAR.ASL_Quant_Params is [Labeltime_ms Delaytime_ms  Slicetime_ms TE_ms Labeling_Efficiency SubtractionOrder]
         Labeltime_ms = PAR.ASL_Quant_Params(1);
         Delaytime_ms = PAR.ASL_Quant_Params(2);
         Slicetime_ms = PAR.ASL_Quant_Params(3);
         TE_ms        = PAR.ASL_Quant_Params(4);
         Labeling_Efficiency = PAR.ASL_Quant_Params(5);
         SubtractionOrder    = PAR.ASL_Quant_Params(6);

         %now supporting the option to extend the ASL_Quant_Params vector
         %to specify post-label delays that are specific for each ASL
         %iteration.  When doing this, the value in ASL_Quant_Params(2) is
         %overwritten by these values.  TF 15 June 2020
         if (size(PAR.ASL_Quant_Params,2) >= (6+c)) 
            Delaytime_ms = PAR.ASL_Quant_Params(6+c);
         end
         
      %   ASL_Type = 0; % NOW SET AS A FUNCTION PARAMETER % 0==PASL, 1==pCASL
         MaskFlag    = 1;
         MeanFlag    = 1;
         CBFFlag     = 1; 
         BOLDFlag    = 0;
         OutPerfFlag = 1;
         OutCBFFlag  = 1;
         QuantFlag   = 0;
         ImgFormatFlag = 1;
         D4Flag        = 1;
         M0wmcsfFlag   = 0;
         OutliersNANFlag  = 0; 
         DumpCBF_DataFlag = 0;
         M0csf = [];
         M0wm = [];
         threshold = [];
         T1blood= [];
         
         if (OutlierMode<=4)
         elseif (OutlierMode==5)
            %try a different approach.  Use meanASL as the M0!
            M0img =  spm_select('ExtFPList', PAR.condirs{s,c}, ['^mean' PAR.confilters{1} '\w*\.nii$'], 1:1000 );
         elseif (OutlierMode==6)
            %try a different approach.  Use constant 1000 for M0 value in denominator of 
            % CBF equation; and also , eliminate the use of qTI.
            
            M0img =  [];
            M0wmcsfFlag = 0;
            QuantFlag   = 1;
            
            M0b = 1000;
            Rwm = 1.19;
            T2wm = 44.7;
            T2b = 43.6;
            qTI = 0.85;
            
            
            M0wm = M0b / (Rwm*exp( (1/T2wm-1/T2b)*TE_ms)*qTI) ;   
            %The formula used in CWRU_perf_subtract to compute M0b is:
            %     M0b=M0wm*Rwm*exp( (1/T2wm-1/T2b)*TE);
            %Also, there is a factor of qTI in the denominator of the CBF equation.
            %If we want to set the normalizing value to 1000, just back calculate to 
            % get a value of M0wm that will result in an effective M0b of 1000 (and also 
            % eliminate the effect of qTI)
            % TF 3 Nov 2017
         elseif (OutlierMode==7)
            %use precomputed cbf from Siemens
            
            %PrecomputedCBF_File =  spm_select('ExtFPList', PAR.condirs{s,c}, ['^Precomputed.?CBF\.nii$'], 1);
            PrecomputedCBF_File =  spm_select('ExtFPList', PAR.condirs{s,c}, ['^relCBF\.nii$'], 1);

         end
         
         switch OutlierMode
            case {1,5, 6, 7, 9, 10}  %outliers on average +/- 2sigma
               ExcludeOutliersEachPerfusion    = 0;   %0: outliers excluded on Average CBF; 1: outlier excluded on each CBF map (perfusion pair)
               OutlierThresholds_IsFixedValues = 0;   %0: OutlierThresholds is range of sigmas from mean; 1: OutlierThresholds is fixed values 
               OutlierThresholds = [-2 2];

            case 2  %outliers on each +/- 2sigma
               ExcludeOutliersEachPerfusion    = 1;   %0: outliers excluded on Average CBF; 1: outlier excluded on each CBF map (perfusion pair)
               OutlierThresholds_IsFixedValues = 0;   %0: OutlierThresholds is range of sigmas from mean; 1: OutlierThresholds is fixed values 
               OutlierThresholds = [-2 2];

            case 3 %outliers on average -40 +150
               ExcludeOutliersEachPerfusion    = 0;   %0: outliers excluded on Average CBF; 1: outlier excluded on each CBF map (perfusion pair)
               OutlierThresholds_IsFixedValues = 1;   %0: OutlierThresholds is range of sigmas from mean; 1: OutlierThresholds is fixed values 
               OutlierThresholds = [-40 150];

            case 4 %outliers on each -40 +150
               ExcludeOutliersEachPerfusion    = 1;   %0: outliers excluded on Average CBF; 1: outlier excluded on each CBF map (perfusion pair)
               OutlierThresholds_IsFixedValues = 1;   %0: OutlierThresholds is range of sigmas from mean; 1: OutlierThresholds is fixed values 
               OutlierThresholds = [-40 150];

            case 11 %outliers on average 0 +99999  ; this is to eliminate all CBF voxels below 0
               ExcludeOutliersEachPerfusion    = 0;   %0: outliers excluded on Average CBF; 1: outlier excluded on each CBF map (perfusion pair)
               OutlierThresholds_IsFixedValues = 1;   %0: OutlierThresholds is range of sigmas from mean; 1: OutlierThresholds is fixed values 
               OutlierThresholds = [0 99999];
         end
         
         Flags = [MaskFlag  MeanFlag  CBFFlag  BOLDFlag  OutPerfFlag OutCBFFlag QuantFlag ImgFormatFlag D4Flag M0wmcsfFlag OutliersNANFlag DumpCBF_DataFlag ExcludeOutliersEachPerfusion OutlierThresholds_IsFixedValues];

         Foldername_TPMs=[];
         if SegmentByTPM 
             Foldername_TPMs = PAR.structdir{s};
         end
         
         %look for special settings that were read from the local
         %processing_settings file.
         for i=1:length(processing_settings)
            switch processing_settings(i).Name
               case 'T1blood'
                  T1blood = str2double(processing_settings(i).Value)
            end             
         end
             
         
         
         
         
         CWRU_perf_subtract(P, 0, 0, ...
            SubtractionOrder,     Flags, ...
            0.5,     ASL_Type,      Labeling_Efficiency, 1,...
            Labeltime_ms/1000, Delaytime_ms/1000, Slicetime_ms, TE_ms, M0img, [], maskimg, ...
            M0csf, M0wm, threshold, ...
            Foldername_TPMs , OutlierThresholds, PrecomputedCBF_File, PrecomputedCBF_Scaling, ...
            T1blood);

      end
   end
   
end
