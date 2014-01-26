function [Cube,SegmentsInfo]=sedm_reduce_image(varargin)
%--------------------------------------------------------------------------
% sedm_reduce_image function                                          SEDM
% Description: Wrapper around sedm_refine_slopepos, sedm_extract_spexcell,
%              sedm_copy_wavecalib.m and sedm_segments2cube.m.
%              Given an IFU image from SEDM and the wavelength calibrated
%              SegmentsInfo structure, this function produce the
%              wavelength calibrated cube.
% Input  : * Arbitrary number of pairs of ...,key,val,.. arguments.
%            The following keywords are available:
%            'Image'    - Single or many IFU FITS image name to reduce.
%                         See create_list.m for options.
%                         This parameter must be provided.
%            'WSI'      - Wavelength calibrated SegmentsInfo structure
%                         array returned by sedm_wavecalib.m.
%                         This can be either a structure array or a mat
%                         file name that contains the structure array.
%                         This parameter must be provided.
%            'SI'       - Basic SegmentsInfo structure array returned by
%                         sedm_generate_spexcell_segmentation.m.
%                         This can be either a structure array or a mat
%                         file name that contains the structure array.
%                         Default is 'Segmentation.mat'.
%            'InvTran'  - Structure containing the transmission information
%                         as generated by spec_fluxcalib.m.
%                         Alternatively this can be a mat file name
%                         containing the structure.
%                         If empty then don't correct for transmission.
%                         Default is 'sedm_InvTran.mat'.
%            'KeyAlt'   - Header keyword containing Altitude in deg.
%                         Default is 'EL'.
%            'KeyExpTime' - Header keyword containing exposure time in s.
%                         Default is 'EXPTIME'.

%            'SaveSI'   - Save SegmentsInfo information to mat file.
%                         This is the file name extension to the image
%                         name. Default is '_SI.mat'.
%            'SaveCube' - Save Cube to mat file.
%                         This is the file name extension to the image
%                         name. Default is '_Cube.mat'.

%            'SlopePar' - A cell array of key,val,... input arguments
%                         to pass to sedm_refine_slopepos.m.
%                         Default is {}.
%            'ExtractPar' - A cell array of key,val,... input arguments
%                         to pass to sedm_extract_spexcell.m.
%                         Default is {}.
%            'SI2Cube'  - A cell array of key,val,... input arguments
%                         to pass to sedm_segments2cube.m.
%                         Default is {}.
%            'Verbose'  - Print status messages {true|false}.
%                         Default is true.
% Output : - A cube structure (see sedm_segments2cube.m for details).
%            An additional field .FluxCalib is attached to the cube.
%            This is the conversion factor from ADU to flux
%            [erg/cm^2/s/Ang].
%          - SegmentsInfo structure array with the wavelength calibration
%            information.
% Tested : Matlab R2011b
%     By : Eran O. Ofek                    Sep 2013
%    URL : http://weizmann.ac.il/home/eofek/matlab/
% Example: [Cube1,SegmentsInfo1]=sedm_reduce_image('Image','b_ifu20130809_22_42_46.fits','WSI',CArcHgXeSegmentsInfo)
% [Cube,SegmentsInfo]=sedm_reduce_image('Image','b_ifu20130809_17_52_38.fits','WSI','WaveSI.mat')
% Reliable: 
%--------------------------------------------------------------------------
RAD       = 180./pi;
WaveField = 'WaveCalib';
NM_TO_ANG = 10;

DefV.Image         = [];
DefV.WSI           = [];
DefV.SI            = 'Segmentation.mat';
DefV.SlopePar      = {};
DefV.ExtractPar    = {};
DefV.SI2Cube       = {};
DefV.InvTran       = 'sedm_InvTran.mat';
DefV.KeyAlt        = 'EL';
DefV.KeyExpTime    = 'EXPTIME';
DefV.Ext           = 'KPNO_atmospheric_extinction.dat';
DefV.SmoothObs     = 'none';                                                 
DefV.R             = 500;                                                    
DefV.InterpMethod  = 'linear';
DefV.SaveSI        = '_SI.mat';
DefV.SaveCube      = '_Cube.mat';
DefV.Verbose       = true;

InPar = set_varargin_keyval(DefV,'y','use',varargin{:});

if (isempty(InPar.Image)),
    error('Image must be provided');
end
if (isempty(InPar.WSI)),
    error('Wavelength calibrated SegmentsInfo must be provided');
end

if (ischar(InPar.WSI)),
    InPar.WSI = load2(InPar.WSI);
end

% check if SI is calibrated
if (~isfield(InPar.WSI,WaveField)),
    error('SegmentsInfo must contain wavelength calibration information');
end

if (ischar(InPar.SI)),
    InPar.SI = load2(InPar.SI);
end


if (ischar(InPar.InvTran)),
    Tran = load2(InPar.InvTran);
else
    Tran = InPar.InvTran;
end

[~,ListCell] = create_list(InPar.Image,NaN);
Nim = length(ListCell);

for Iim=1:1:Nim,
    ImageName = ListCell{Iim};

    if (InPar.Verbose)
        fprintf('Reduce image # %d\n',Iim);
        fprintf('   Image name: %s\n',ImageName);
    end
    
    % find veryical shifts of segments
    [SegmentsInfo,OffsetSurface]=sedm_refine_slopepos('Input',ImageName,...
                                                      'SI',InPar.SI,...
                                                      InPar.SlopePar{:});

    % extract trace for each segment
    SegmentsInfo=sedm_extract_spexcell('SI',SegmentsInfo,...
                                       'ScienceImage',ImageName,...
                                       InPar.ExtractPar{:});

    % copy wave calib info                                  
    SegmentsInfo=sedm_copy_wavecalib(InPar.WSI,SegmentsInfo);

    % generate the Cube
    [Cube,SegmentsInfo]=sedm_segments2cube('SI',SegmentsInfo,InPar.SI2Cube{:});

    % Attach flux calibration information to cube

    % ADU_airless*InvTran = Flux_airless
    InvTran = interp1(Tran.Wave, Tran.InvTran, Cube.Wave.*NM_TO_ANG, InPar.InterpMethod);

    % get AM/ExpTime from header
    [~,KeywordS] = mget_fits_keyword(ImageName,{InPar.KeyAlt,InPar.KeyExpTime,'OBJECT','RA','DEC','OBRA','OBDEC','NAME','JD'});
    AM = hardie((90-KeywordS.(InPar.KeyAlt))./RAD);
    ExpTime = KeywordS.(InPar.KeyExpTime);

    %    
    AM2Airless = atmospheric_ext([Cube.Wave.*NM_TO_ANG,ones(size(Cube.Wave))],...
                                 AM,...
                                 InPar.Ext);

                             
                 
    Cube.FluxCalib = InvTran.*AM2Airless(:,2)./ExpTime;   % CHECK

    % append some additional info to Cube
    Cube.KeywordS = KeywordS;

    if (~isempty(InPar.SaveSI)),
        SI_FileName = sprintf('%s%s',ImageName,InPar.SaveSI);
        save(SI_FileName,'SegmentsInfo');
    end
    if (~isempty(InPar.SaveCube)),
        Cube_FileName = sprintf('%s%s',ImageName,InPar.SaveCube);
        save(Cube_FileName,'Cube');
    end

end