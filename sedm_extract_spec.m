function Spectra=sedm_extract_spec(varargin)
%--------------------------------------------------------------------------
% sedm_extract_spec function                                          SEDM
% Description: 
%   Performs "sedm_extract_spec_cube" over a list of spectra. The spectra
%   are stored to disk in _Spec.mat files.
%   
% Input  : * Arbitrary number of pairs of ...,key,val,.. arguments.
%            The following keywords are available:
%            'Image'    - Single or many IFU FITS image name to reduce.
%                         See create_list.m for options.
%                         This parameter must be provided.
%                         This can be either a structure array or a mat
%                         file name that contains the structure array.
%             'Verbose' - Verbose
% Output : - A spec sctructure (see sedm_extract_spec_cube)
% Tested : 
%     By : Nick Konidaris                       Jan 2014
%    URL : http://weizmann.ac.il/home/eofek/matlab/
% Example: 
% 
% Reliable: 
%--------------------------------------------------------------------------
RAD       = 180./pi;
WaveField = 'WaveCalib';
NM_TO_ANG = 10;

DefV.Image         = [];
DefV.Verbose       = true;

InPar = set_varargin_keyval(DefV,'y','use',varargin{:});

if (isempty(InPar.Image)),
    error('Image must be provided');
end

[~,ListCell] = create_list(InPar.Image,NaN);
Nim = length(ListCell);
Spectra = 0;

for Iim=1:1:Nim,
    ImageName = ListCell{Iim};

    if (InPar.Verbose)
        fprintf('Handling image # %d\n',Iim);
        fprintf('    Image name: %s\n',ImageName);
    end
    Cube = load(strcat(ImageName, '_Cube.mat'));
    Cube = Cube.Cube;

    Spec = sedm_extract_spec_cube('Cube', Cube);

    outf = strcat(ImageName, '_Spec.mat');
    if (InPar.Verbose)
        fprintf('Writing to: %s\n', outf)
    end
    save(outf, 'Spec')

end
