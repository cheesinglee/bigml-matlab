classdef BigML
    %BIGML Summary of this class goes here
    %   Detailed explanation goes here
    
    properties ( SetAccess = immutable )
        % Base Domain
        BIGML_DOMAIN = 'bigml.io' ;

        % Base URL
        BIGML_URL = 'https://bigml.io/andromeda/' ;

        % Development Mode URL
        BIGML_DEV_URL = 'https://bigml.io/dev/andromeda/' ;

        % Prediction URL
        BIGML_PREDICTION_URL = 'https://bigml.io/andromeda/' ;

        % Basic resources
        SOURCE_PATH = 'source' ;
        DATASET_PATH = 'dataset' ;
        MODEL_PATH = 'model' ;
        PREDICTION_PATH = 'prediction' ;
        EVALUATION_PATH = 'evaluation' ;
        ENSEMBLE_PATH = 'ensemble' ;
        BATCH_PREDICTION_PATH = 'batchprediction' ;

        % HTTP Status Codes from https://bigml.com/developers/status_codes
        HTTP_OK = 200 ;
        HTTP_CREATED = 201 ;
        HTTP_ACCEPTED = 202 ;
        HTTP_NO_CONTENT = 204 ;
        HTTP_BAD_REQUEST = 400 ;
        HTTP_UNAUTHORIZED = 401 ;
        HTTP_PAYMENT_REQUIRED = 402 ;
        HTTP_FORBIDDEN = 403 ;
        HTTP_NOT_FOUND = 404 ;
        HTTP_METHOD_NOT_ALLOWED = 405 ;
        HTTP_LENGTH_REQUIRED = 411 ;
        HTTP_INTERNAL_SERVER_ERROR = 500 ;

        % Resource status codes
        WAITING = 0 ;
        QUEUED = 1 ;
        STARTED = 2 ;
        IN_PROGRESS = 3 ;
        SUMMARIZED = 4 ;
        FINISHED = 5 ;
        UPLOADING = 6 ;
        FAULTY = -1 ;
        UNKNOWN = -2 ;
        RUNNABLE = -3 ;     
    end
    
    properties
        auth
        url
        prediction_url
        source_url
        dataset_url
        model_url
        evaluation_url
        ensemble_url
        batch_prediction_url
    end
    
    methods
        %%%%%%%%%%%% Constructor %%%%%%%%%%%%%
        function self = BigML(varargin)
            p = inputParser() ;
            p.addParamValue( 'username',getenv('BIGML_USERNAME'),@(x)ischar(x) ) ;
            p.addParamValue( 'apikey', getenv('BIGML_API_KEY'), @(x)ischar(x) ) ;
            p.addParamValue( 'devmode', false, @(x) islogical(x) ) ;

            p.parse(varargin{:}) ;
            arglist = p.Results ;

            if ( strcmp(arglist.username,'') )
                error('Can not find BIGML_USERNAME in your environment, and none was given') ;
            end

            if ( strcmp(arglist.apikey,'') )
                error('Can not find BIGML_API_KEY in your environment, and none was given') ;
            end

            self.auth = sprintf('?username=%s;api_key=%s',arglist.username,arglist.apikey) ;

            if (arglist.devmode)
                self.url = self.BIGML_DEV_URL ;
                self.prediction_url = self.BIGML_DEV_URL ;
            else
                self.url = self.BIGML_URL ;
                self.prediction_url = self.BIGML_PREDICTION_URL ;
            end

            % Base Resource URLs
            self.source_url = [self.url, self.SOURCE_PATH] ;
            self.dataset_url = [self.url, self.DATASET_PATH] ;
            self.model_url = [self.url, self.MODEL_PATH] ;
            self.prediction_url = [self.prediction_url, self.PREDICTION_PATH] ;
            self.evaluation_url = [self.url, self.EVALUATION_PATH] ;
            self.ensemble_url = [self.url, self.ENSEMBLE_PATH] ;
            self.batch_prediction_url = [self.url, self.BATCH_PREDICTION_PATH] ;
        end 
        
        %%%%%%%% Sources %%%%%%%%%
        function response = get_source(self,source)
            res = get_res_id(source) ;
            url = [self.url,res,self.auth] ;
            response = urlread2(url,'GET') ;
        end
        
        function response = create_local_source(self,file_name)
           % read binary data from file
           f = fopen(file_name) ;
           d = fread(f,inf,'*uint8') ;
           fclose(f) ;

           response = urlreadpost([self.source_url,self.auth],...
               {'name',file_name,'filename',file_name,'data',d}) ;

           response = parse_json(response) ;
           response = response{1} ;
        end

        function response = create_remote_source(self,url,params)
           params.remote = url ;
           params.name = url ;
           body = jsonify(params) ;
           disp(body)

           header = http_createHeader('Content-Type',...
               'application/json;charset=utf-8') ;

           response = urlread2([self.source_url,self.auth],'POST',body,header) ;

           response = parse_json(response) ;
           response = response{1} ;
        end

        function response = create_inline_source(self,data,params)
            csv_data = self.struct_to_csv(data) ;
            params.data = csv_data ;
            body = jsonify(params) ;

            header = http_createHeader('Content-Type',...
              'application/json;charset=utf-8') ;
            response = urlread2([self.source_url,self.auth],'POST',body,header) ;

            response = parse_json(response) ;
            response = response{1} ;
        end
        
        function ready = source_is_ready(self,source)
            source = self.get_source(source) ;
            ready = resource_is_ready(source) ;
        end
        
        %%%%%%%%%%% Datasets %%%%%%%%%%%%
        function response = create_dataset(self,source,params)
            if ~exist('params','var')
                params = {} ;
            end
            
            src_res = get_res_id(source) ;
            
            params.source = src_res ;
            body = jsonify(params) ;
            disp(body) 
            header = http_createHeader('Content-Type',...
                'application/json;charset=utf-8') ;
            
            response = urlread2([self.dataset_url,self.auth],'POST',body,header) ;

            response = parse_json(response) ;
            response = response{1} ;
        end
    end
    
    methods (Static=true)
        function csv_string = struct_to_csv(struct_array)
            s = struct_array(1) ;
            names = fieldnames(s) ;
            csv_string = '' ;
            
            % header line
            for j = 1:length(names)
                if (j == 1)
                    s = names{j} ;
                else
                    s = [',',names{j}] ;
                end
                csv_string = [csv_string,s] ;
            end
            csv_string = [csv_string,'\n'] ;
            
            % content
            for i = 1:length(struct_array)
                for j = 1:length(names)
                    s = struct_array(i).(names{j}) ;
                    if isnumeric(s)
                        s = num2str(s) ;
                    end
                    
                    if (j > 1)
                        s = [',',s] ;
                    end
                        
                    csv_string = [csv_string,s] ;
                end
                
                if i < length(struct_array)
                    csv_string = [csv_string,'\n'] ;
                end
            end
        end
    end
    
    methods (Access = private)
        function define_constants_(self)
        end
    end
    
end

function res = get_res_id(r)
    if ischar(r)
        res = r ;
    elseif isstruct(r)
        res = r.source ;
    end
end

function ready = resource_is_ready(res)
    
end

function quoted = quotify(s,single)
% enclose a string in double quotes
    assert(ischar(s)) ;
    if (~exist('single','var') || ~single)
        quoted = ['"',s,'"'] ;
    else
        quoted = ['''',s,''''] ;
    end
end


function list = cell2json(a)
    % transform a MATLAB cell array into a JSON array
    list = '[' ;
    for i = 1:length(a)
        val = jsonify(a{i}) ;
        if (i > 1)
            val = [',',val] ;
        end
        list = [list,val] ;
    end
    list = [list,']'] ;
end

function j = jsonify(val)
    if ischar(val)
        j = quotify(val) ;
    elseif isnumeric(val)
        j = num2str(val) ;
    elseif iscell(val)
        j = cell2json(val) ;
    elseif isstruct(val) && length(val) == 1
        j = struct2json(val) ;
    else
        error('Unable to jsonify: ') ;
        disp(val) ;
    end
end

function json = struct2json(structure)
    % JSON-encode a MATLAB structure
    
    json = '{' ;
    fields = fieldnames(structure) ;
    for i = 1:length(fields) 
        val = jsonify(structure.(fields{i})) ;
        json = [json,quotify(fields{i}),' : ',val] ;
        if (i < length(fields))
            json = [json,','];
        else
            json = [json,'}'] ;
        end
    end
    
%     for i = 1:2:length(params)
%         name = quotify(params{i}) ;
%         val = params{i+1} ;
%         
%         if ischar(val)
%             val = quotify(val) ;
%         elseif isnumeric(val)
%             val = num2str(val) ;
%         elseif iscell(val)
%             val = encode_json(val) ;
%         end
%         
%         json = [json,name,' : ',val] ;
%         if (i+1 < length(params))
%             json = [json,','] ;
%         else
%             json = [json,'}'] ;
%         end
%     end
end

