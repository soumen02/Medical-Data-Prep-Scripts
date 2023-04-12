
clear all

PARENT_DIR = '/Volumes/Maves_CCAD_segmentations/Main_maves_seg';

S = dir(fullfile(PARENT_DIR, '*SUBDIR'));

for d = 1:length(S)
    fullsubdir = fullfile(PARENT_DIR, S(d).name);
    fprintf(1, 'SUBDIR: %s\n', S(d).name);
    
    Subjects = dir(fullfile(fullsubdir, '*DICOM'));
    
    for f = 1:length(Subjects)
           
        clearvars -except PARENT_DIR S Subjects d f fullsubdir fullsubjectpath
        
        fullsubjectpath = fullfile(fullsubdir, Subjects(f).name);
        fprintf(1, 'SUBJECT: %s\n', Subjects(f).name);


        patient_path = fullsubjectpath;
        cd(patient_path)
        
%         if isfolder('new_final_conversion')
%             fprintf('subject already done\n');
%             continue
%         end
 

        % creates a structure including all .dcm files in patient_path
        dcmFiles = dir(fullfile(patient_path, '*.dcm'));

        %structures to store dicom files and corresponding rtstruct files
        dicom_filename_all = {};
        rtstruct_filename_all = {};


        % iterate through structure dcmfiles
        for k = 1:length(dcmFiles)

            baseFileName = dcmFiles(k).name;
            fullFileName = fullfile(patient_path, baseFileName);
            fprintf(1, 'Now reading %s\n', baseFileName);

            % ignore biliary files from conversion
            if contains(baseFileName, '_biliary', 'IgnoreCase',true) == 0
                % store files containing ROI_RT in rtstruct_filename_all
               if contains(baseFileName, 'ROI_RT')
                   rtstruct_filename_all{end+1} = fullFileName;
               % store files containing ROI in dicom_filename_all
               elseif contains(baseFileName, 'ROI')
                   dicom_filename_all{end+1} = fullFileName;

                   % PV CT volume is assigned fixedVolume for registration 
                   if contains(baseFileName, '_venous')
                       fixedVolume = fullFileName;
                   end
               end
            end
        end
        
        if (numel(rtstruct_filename_all)==0 || numel(dicom_filename_all)==0)
            for k = 1:length(dcmFiles)
                baseFileName = dcmFiles(k).name;
                fullFileName = fullfile(patient_path, baseFileName);
                
%                 fprintf('\n%s', baseFileName);
                
                if contains(baseFileName, '_arterial.dcm', 'IgnoreCase',true)
%                     fprintf('1');
                    dicom_filename_all{end+1} = fullFileName;
                elseif (contains(baseFileName, '_arterial_RT.dcm', 'IgnoreCase',true))
                    rtstruct_filename_all{end+1} = fullFileName;
%                     fprintf('2');
                elseif (contains(baseFileName, '_venous.dcm', 'IgnoreCase',true))
                    dicom_filename_all{end+1} = fullFileName;
                    fixed = fullFileName;
%                     fprintf('3');
                 elseif (contains(baseFileName, '_venous_RT.dcm', 'IgnoreCase',true) )
                    rtstruct_filename_all{end+1} = fullFileName;
%                     fprintf('4');
                   elseif ((contains(baseFileName, '_latevenous.dcm', 'IgnoreCase',true)) || (contains(baseFileName, '_late venous.dcm', 'IgnoreCase',true) ))
                    dicom_filename_all{end+1} = fullFileName;
%                     fprintf('5');
                 elseif ((contains(baseFileName, '_latevenous_RT.dcm', 'IgnoreCase',true) ) || (contains(baseFileName, '_late venous_RT.dcm', 'IgnoreCase',true) ))
                    rtstruct_filename_all{end+1} = fullFileName;
%                     fprintf('6');
                end    
            end   
        end


        % loop to iterate through the three files (HA, PV, HV) in 
        for jj = 1:numel(dicom_filename_all)

          fprintf(1, 'DCM : %s\n', dicom_filename_all{jj});
          dicom_filename = dicom_filename_all{jj};
          fprintf(1, 'RT : %s\n', rtstruct_filename_all{jj});
          rtstruct_filename = rtstruct_filename_all{jj};

          liverflag = 0;

          info = dicominfo(rtstruct_filename);
          contour = dicomContours(info);


          % plots the figures (commented to save time)
        %   figure, plotContour(contour)

            ct_info = dicominfo(dicom_filename);
          [im, spatial]=dicomreadVolume(dicom_filename);

          rtMask = zeros(size(squeeze(im)));
          liver_mask = zeros(size(squeeze(im)));
          fn = fieldnames(info.ROIContourSequence);

          for contourIndex=1:numel(fn)
            if contains(contour.ROIs.Name(contourIndex) , 'Liver', 'IgnoreCase',true)
              liverflag = 1;
              liver_mask = liver_mask + createMask(contour,contourIndex,spatial);
        %       figure,volshow(liver_mask);
            else
              rtMask = rtMask + createMask(contour,contourIndex,spatial);
            end
          end
        %   figure,volshow(rtMask);

          if contains(dicom_filename, '_venous', 'IgnoreCase',true)


            niftiwrite(double(squeeze(im)),'temp-PV-PVreg', 'Compressed', true);
            writeinfoPVvol = niftiinfo('temp-PV-PVreg.nii.gz');
            writeinfoPVvol.PixelDimensions = [ct_info.SharedFunctionalGroupsSequence.Item_1.PixelMeasuresSequence.Item_1.PixelSpacing(1), ct_info.PixelSpacing(2), ct_info.SharedFunctionalGroupsSequence.Item_1.PixelMeasuresSequence.Item_1.SliceThickness(1)];
            writeinfoPVvol.SpaceUnits = 'Millimeter';
            niftiwrite(double(squeeze(im)),sprintf('%s_PV-PVreg', ct_info.PatientID), writeinfoPVvol, 'Compressed', true);
            delete temp-PV-PVreg.nii.gz;
            fprintf(1, 'PV-PVreg completed...\n');


            rtMask(rtMask>0)=1;
            niftiwrite(double(rtMask),'temp-PV-label-PVreg', 'Compressed', true);
            writeinfoPVlabel = niftiinfo('temp-PV-label-PVreg.nii.gz');
            writeinfoPVlabel.PixelDimensions = [ct_info.SharedFunctionalGroupsSequence.Item_1.PixelMeasuresSequence.Item_1.PixelSpacing(1), ct_info.PixelSpacing(2), ct_info.SharedFunctionalGroupsSequence.Item_1.PixelMeasuresSequence.Item_1.SliceThickness(1)];
            writeinfoPVlabel.SpaceUnits = 'Millimeter';
            niftiwrite(double(rtMask),sprintf('%s_PV-label-PVreg', ct_info.PatientID), writeinfoPVlabel, 'Compressed', true);
            delete temp-PV-label-PVreg.nii.gz;
            fprintf(1, 'PV-label-PVreg completed...\n');

            continue;
          end

            moving = squeeze(dicomreadVolume(dicom_filename));
            fixed = squeeze(dicomreadVolume(fixedVolume));


            [deformationField,movingReg] = imregdemons(moving,fixed,[300 300 200],...
            'AccumulatedFieldSmoothing',1.3);

         rtmask_reg = imwarp(rtMask,deformationField);
         rtmask_reg(rtmask_reg>0) = 1;

         if contains(dicom_filename, '_arterial', 'IgnoreCase',true)

            niftiwrite(double(squeeze(movingReg)),'temp-HA-PVreg', 'Compressed', true)
            writeinfoHAvol = niftiinfo('temp-HA-PVreg.nii.gz');
            writeinfoHAvol.PixelDimensions = [ct_info.SharedFunctionalGroupsSequence.Item_1.PixelMeasuresSequence.Item_1.PixelSpacing(1), ct_info.PixelSpacing(2), ct_info.SharedFunctionalGroupsSequence.Item_1.PixelMeasuresSequence.Item_1.SliceThickness(1)];
            writeinfoHAvol.SpaceUnits = 'Millimeter';
            niftiwrite(double(squeeze(movingReg)),sprintf('%s_HA-PVreg', ct_info.PatientID), writeinfoHAvol, 'Compressed', true);
            delete temp-HA-PVreg.nii.gz;
            fprintf(1, 'HA-PVreg completed...\n');

            niftiwrite(double(rtmask_reg),'temp-HA-label-PVreg', 'Compressed', true)
            writeinfoHAlabel = niftiinfo('temp-HA-label-PVreg.nii.gz');
            writeinfoHAlabel.PixelDimensions = [ct_info.SharedFunctionalGroupsSequence.Item_1.PixelMeasuresSequence.Item_1.PixelSpacing(1), ct_info.PixelSpacing(2), ct_info.SharedFunctionalGroupsSequence.Item_1.PixelMeasuresSequence.Item_1.SliceThickness(1)];
            writeinfoHAlabel.SpaceUnits = 'Millimeter';
            niftiwrite(double(rtmask_reg),sprintf('%s_HA-label-PVreg', ct_info.PatientID), writeinfoHAlabel, 'Compressed', true);
            delete temp-HA-label-PVreg.nii.gz;
            fprintf(1, 'HA-label-PVreg completed...\n');

         elseif contains(dicom_filename, '_latevenous', 'IgnoreCase',true)

             niftiwrite(double(squeeze(movingReg)),'temp-HV-PVreg', 'Compressed', true)
             writeinfoHVvol = niftiinfo('temp-HV-PVreg.nii.gz');
            writeinfoHVvol.PixelDimensions = [ct_info.SharedFunctionalGroupsSequence.Item_1.PixelMeasuresSequence.Item_1.PixelSpacing(1), ct_info.PixelSpacing(2), ct_info.SharedFunctionalGroupsSequence.Item_1.PixelMeasuresSequence.Item_1.SliceThickness(1)];
            writeinfoHVvol.SpaceUnits = 'Millimeter';
            niftiwrite(double(squeeze(movingReg)),sprintf('%s_HV-PVreg', ct_info.PatientID), writeinfoHVvol, 'Compressed', true);
            delete temp-HV-PVreg.nii.gz;
             fprintf(1, 'HV-PVreg completed...\n');

             niftiwrite(double(rtmask_reg),'temp-HV-label-PVreg', 'Compressed', true)
             writeinfoHVlabel = niftiinfo('temp-HV-label-PVreg.nii.gz');
            writeinfoHVlabel.PixelDimensions = [ct_info.SharedFunctionalGroupsSequence.Item_1.PixelMeasuresSequence.Item_1.PixelSpacing(1), ct_info.PixelSpacing(2), ct_info.SharedFunctionalGroupsSequence.Item_1.PixelMeasuresSequence.Item_1.SliceThickness(1)];
            writeinfoHVlabel.SpaceUnits = 'Millimeter';
            niftiwrite(double(rtmask_reg),sprintf('%s_HV-label-PVreg', ct_info.PatientID), writeinfoHVlabel, 'Compressed', true);
            delete temp-HV-label-PVreg.nii.gz;
             fprintf(1, 'HV-label-PVreg completed...\n');

         end

         if liverflag == 1
            liver_mask_reg = imwarp(liver_mask, deformationField);
            liver_mask_reg(liver_mask_reg>0)=1;
            niftiwrite(double(liver_mask_reg),'temp-Liver-label-PVreg', 'Compressed', true)
            writeinfoLIVlabel = niftiinfo('temp-Liver-label-PVreg.nii.gz');
            writeinfoLIVlabel.PixelDimensions = [ct_info.SharedFunctionalGroupsSequence.Item_1.PixelMeasuresSequence.Item_1.PixelSpacing(1), ct_info.PixelSpacing(2), ct_info.SharedFunctionalGroupsSequence.Item_1.PixelMeasuresSequence.Item_1.SliceThickness(1)];
            writeinfoLIVlabel.SpaceUnits = 'Millimeter';
            niftiwrite(double(liver_mask_reg),sprintf('%s_Liver-label-PVreg', ct_info.PatientID), writeinfoLIVlabel, 'Compressed', true);
            delete temp-Liver-label-PVreg.nii.gz;
            fprintf(1, 'Liver-label-PVreg completed...\n');
         end
        end
        
        % next part of the code waits for the 7 files to finish before
        % starting to copy the files to the new_final_conversion folder
        copyreadyflag = 1;
        while(copyreadyflag == 1)
            checkfiles = dir(fullfile(patient_path, '*.nii.gz'));
            if (numel(checkfiles) == 7)
                copyreadyflag = 0;
            end
        end
        
        
        try
        copyfile *.nii.gz new_final_conversion
        delete *.nii.gz
        catch
            fprintf('ERROR in copy and delete\n');
        end
        fprintf('copied to folder successfully\n');
    
        

    end
end

