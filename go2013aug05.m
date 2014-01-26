

% Identify bias images, construct super bias,
% and subtract it from all images.
% for both IFU and RC images.
% result will be written into 'b_*'.

% Modified by NPK:
%sedm_bias_subtraction_npk


% get OBJECT keyword from all images
HeadKeys = {'OBJECT','AZ','EL','JD','EXPTIME','GAIN_SET','ADC','NAME','RA','DEC','OBRA','OBDEC'};
[~,ListCell] = create_list('b_ifu*.fits');
[~,KeywordS] = mget_fits_keyword(ListCell,HeadKeys);
Stat         = imstat_fits(ListCell);

ImSize = [Stat(1).NAXIS1, Stat(1).NAXIS2];

InPar.IFU_SaturationLevel    = 65000;


% In OBJECT keyword replace NaN with ''.
FlagNaN = isnan_cell({KeywordS.OBJECT});
[KeywordS(FlagNaN).OBJECT] = deal('');

   
% identify dome flats -- MODIFIED BY NPK
FlagDomeFF = strcmp({KeywordS.OBJECT}, '');

% identify sky flats
FlagSkyFF  = (isempty_cell(strfind({KeywordS.OBJECT},'twilight flat'))==0) & ...
             [Stat.Max]<InPar.IFU_SaturationLevel;
         
% identify Hg lamp - MODIFIED BY NPK
FlagLampHg  = (isempty_cell(strfind({KeywordS.OBJECT},'hg - test'))==0);
FlagLampHg  = strcmp({KeywordS.OBJECT}, 'hg - test')
            
% identify Ne lamp
FlagLampNe  = (isempty_cell(strfind({KeywordS.OBJECT},'neon'))==0);
FlagLampNe  = strcmp({KeywordS.OBJECT}, 'neon')

% identify Xe lamp
FlagLampXe  = (isempty_cell(strfind({KeywordS.OBJECT},''))==0);
FlagLampXe  = strcmp({KeywordS.OBJECT}, 'xenon')


List.DomeFlat = ListCell(FlagDomeFF);
List.SkyFlat  = ListCell(FlagSkyFF);
List.LampHg   = ListCell(FlagLampHg);
List.LampNe   = ListCell(FlagLampNe);
List.LampXe   = ListCell(FlagLampXe);


SlopeType  = 'smooth';
OffsetType = 'smooth';

%%
%----------------------------------------------
%--- generate the segmentation image (once) ---
%----------------------------------------------
load ~/matlab/fun/sedm/Segmentation.mat

%%
%------------------------------
%--- Wavelength calibration ---
%------------------------------

% Hg
ImageName = List.LampHg{1};

tic;
[ArcHgSegmentsInfo,OffsetSurface]=sedm_refine_slopepos('Input',ImageName,...
                                                     'SI',SegmentsInfo,...
                                                     'MultiThred',1,...
                                                     'SlopeType',SlopeType);
toc                                             
% 52s                                              
                                                                                                
% extract spexcells
tic;
ArcHgSegmentsInfo=sedm_extract_spexcell('SI',ArcHgSegmentsInfo,...
                                      'ScienceImage',ImageName,...
                                      'OffsetType',OffsetType);
toc
% 5s

% Xe
ImageName = List.LampXe{1};

[ArcXeSegmentsInfo,OffsetSurface]=sedm_refine_slopepos('Input',ImageName,...
                                                     'SI',SegmentsInfo,...
                                                     'MultiThred',1,...
                                                     'SlopeType',SlopeType);
                                                 
                                                 
                                                                                                
% extract spexcells
ArcXeSegmentsInfo=sedm_extract_spexcell('SI',ArcXeSegmentsInfo,...
                                      'ScienceImage',ImageName,...
                                      'OffsetType',OffsetType);

% combine the Hg+Xe arcs
ArcHgXeSegmentsInfo = ArcXeSegmentsInfo;
for Iseg=1:1:length(ArcHgXeSegmentsInfo),
    ArcHgXeSegmentsInfo(Iseg).SpexSpecFit = ArcXeSegmentsInfo(Iseg).SpexSpecFit+ArcHgSegmentsInfo(Iseg).SpexSpecFit;
end
        


tic;
AbsCalib = sedm_abswavecalib('Template','HgXe',...
                                    'SI',ArcHgXeSegmentsInfo,...
                                    'RefineWaveCalib',true,...
                                    'Plot',true,...
                                    'GridVecX', (1024).',...
                                    'GridVecY', (1024).')

toc
% 132s (for grid=16), 10s (for grid=1)

tic;
CArcHgXeSegmentsInfo=sedm_wavecalib('SI',ArcHgXeSegmentsInfo,'AbsCalib',AbsCalib,'waitbar',true)
toc

[ArcCube,CArcHgXeSegmentsInfo]=sedm_segments2cube('SI',CArcHgXeSegmentsInfo);



% produce movie
Wave                      = logspace(log10(320),log10(1000),200).';
for Ic=1:1:size(ArcCube,1),
   fitswrite(squeeze(ArcCube(Ic,:,:)),sprintf('ArcCube%05d.fits',floor(Wave(Ic).*10)));
end


%%
%----------------
%--- Std star ---
%----------------

I = find(strcmp({KeywordS.OBJECT},'BD+33d2642')==1)
I = I(1);
ScienceImageName = ListCell{I(1)};
SpecStD = search_specphot_stand('BD+33 2642')
ScienceImage     = fitsread(ScienceImageName);
   
[Cube1,SegmentsInfo1]=sedm_reduce_image('WSI',CArcHgXeSegmentsInfo,'Image',ScienceImageName);

tic;
[StdSegmentsInfo,OffsetSurface]=sedm_refine_slopepos('Input',ScienceImageName,...
                                                     'SI',SegmentsInfo1,...
                                                     'SlopeType',SlopeType,...
                                                     'MultiThred',1);
                                                                                                 
                                                 
toc
%


tic;
StdSegmentsInfo=sedm_extract_spexcell('SI',StdSegmentsInfo,...
                                      'ScienceImage',ScienceImageName,...
                                      'OffsetType',OffsetType);

toc
% 5.1s 

% add wavelength solution
StdSegmentsInfo=sedm_copy_wavecalib(CArcHgXeSegmentsInfo,StdSegmentsInfo);

[StdCube,~]=sedm_segments2cube('SI',StdSegmentsInfo);

Spec=sedm_extract_spec_cube('Cube',StdCube,'Aper',[6 12 16])




errorxy([Spec(1).Wave, Spec(1).BS_Source, Spec(1).BS_SourceErr])
ObservedSpec = [Spec(1).Wave.*10, Spec(1).BS_Source];
Tran=spec_fluxcalib(ObservedSpec,'BD+33 2642','Alt',KeywordS(I).EL./RAD,'Ext','KPNO_atmospheric_extinction.dat','ExpTime',KeywordS(I).EXPTIME);

FlagScience = ~isempty_cell(strfind(lower({KeywordS.OBJECT}),'ngc6210'));
ListPN = ListCell(FlagScience);
[Cube,SegmentsInfo]=sedm_reduce_image('WSI',CArcHgXeSegmentsInfo,'Image', ListPN);

FlagScience = ~isempty_cell(strfind(lower({KeywordS.OBJECT}),'ptf'));
ListScience = ListCell(FlagScience);


%%
%-------------------------
%--- Reduce all images ---
%-------------------------
[Cube,SegmentsInfo]=sedm_reduce_image('WSI',CArcHgXeSegmentsInfo,'Image',ListScience);




Spec=sedm_extract_spec_cube('Cube',Cube);



Wave                      = Cube.wave
for Ic=1:1:size(Cube.Cube,1),
   fitswrite(squeeze(Cube.Cube(Ic,:,:)),sprintf('CCube%05d.fits',floor(Wave(Ic).*10)));
end
