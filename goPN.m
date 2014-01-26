

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

SlopeType  = 'smooth';
OffsetType = 'smooth';

%%
%----------------------------------------------
load ~/matlab/fun/sedm/Segmentation.mat

%%
FlagScience = ~isempty_cell(strfind(lower({KeywordS.OBJECT}),'ngc6210'));
ListPN = ListCell(FlagScience);

[Cube,SegmentsInfo]=sedm_reduce_image('WSI',CArcHgXeSegmentsInfo,'Image',ListPN{1});
Spec=sedm_extract_spec_cube('Cube',Cube);



Wave                      = Cube.wave
for Ic=1:1:size(Cube.Cube,1),
   fitswrite(squeeze(Cube.Cube(Ic,:,:)),sprintf('CCube%05d.fits',floor(Wave(Ic).*10)));
end
