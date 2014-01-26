function Stat=sedm_bias_subtraction_npk(varargin)
%--------------------------------------------------------------------------
% sedm_bias_subtraction function                                      SEDM
% Description: Subtract bias from SEDM image/s.
% Input  : - none
% Output : - Structure containing the statistics of the output bias images.
% Tested : Matlab R2011b
%     By : Eran O. Ofek                    Sep 2013
%    URL : http://weizmann.ac.il/home/eofek/matlab/
% Example: sedm_abswavecalib('SI',ArcSegmentsInfo(1130))
% Reliable: 2
%--------------------------------------------------------------------------


DefV.ListAll              = '*.fits';
DefV.ListRed              = [];
DefV.BaseIFU              = 'ifu';
DefV.BaseRC               = 'rc';
DefV.BiasKeyword          = 'bias';
DefV.IFU_BiasImageName    = 'BiasIFU.fits';
DefV.IFU_BiasStDImageName = 'BiasStdIFU.fits';
DefV.RC_BiasImageName     = 'BiasRC.fits';
DefV.RC_BiasStDImageName  = 'BiasStdRC.fits';
DefV.Prefix               = 'b_';
InPar = set_varargin_keyval(DefV,'y','use',varargin{:});

if (isempty(InPar.ListRed)),
   InPar.ListRed = InPar.ListAll;
end


[~,ListCell.Red] = create_list(InPar.ListRed,NaN);
[~,ListCell.All] = create_list(InPar.ListAll,NaN);

ListCell.AllIFU = ListCell.All(find(~isempty_cell(strfind(ListCell.All,InPar.BaseIFU))));
ListCell.AllRC  = ListCell.All(find(~isempty_cell(strfind(ListCell.All,InPar.BaseRC))));


parfor II = 1:length(ListCell.AllIFU)
    Image = fitsread(ListCell.AllIFU{II});
    ImInfo = fitsinfo(ListCell.AllIFU{II});
    OverScan = Image(:, 2045:2048);
    OV = median(OverScan, 2); % The overscan vector
    Bias = repmat(OV, 1, 2048);
    bImage = Image - Bias;
    fitswrite(bImage, strcat('b_', ListCell.AllIFU{II}), ImInfo.PrimaryData.Keywords, ImInfo.PrimaryData.DataType);
end


end


