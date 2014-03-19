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
        
        SOURCE_RE = '^source/[a-f0-9]{24}$' ;
        DATASET_RE = '^(public/)?dataset/[a-f0-9]{24}$' ;
        MODEL_RE = '^(public/)?model/[a-f0-9]{24}$|^shared/model/[a-zA-Z0-9]{27}$' ;
        PREDICTION_RE = '^prediction/[a-f0-9]{24}$' ;
        ENSEMBLE_RE = '^ensemble/[a-f0-9]{24}$' ;
        EVALUATION_RE = '^evaluation/[a-f0-9]{24}$' ;
        BATCHPREDICTION_RE = '^batchprediction/[a-f0-9]{24}$' ;

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
        timeout
        n_tries
    end
    
    methods
        %%%%%%%%%%%% Constructor %%%%%%%%%%%%%
        function self = BigML(varargin)
            p = inputParser() ;
            p.addParamValue( 'username',getenv('BIGML_USERNAME'),@(x)ischar(x) ) ;
            p.addParamValue( 'apikey', getenv('BIGML_API_KEY'), @(x)ischar(x) ) ;
            p.addParamValue( 'devmode', false, @(x) islogical(x) ) ;
            p.addParamValue( 'timeout', 3, @(x) isnumeric(x) && (x > 0)) ;
            p.addParamValue( 'n_tries', 10, @(x) isnumeric(x) && (x > 0)) ;

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
            
            % resource fetching parameters
            self.timeout = arglist.timeout ;
            self.n_tries = arglist.n_tries ;

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
            response = parse_json(urlread2(url,'GET')) ;
            response = response{1} ;
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
            if ~exist('params','var')
                params = containers.Map() ;
            end
           params('remote') = url ;
           params('name') = url ;
           body = jsonify(params) ;
           disp(body)

           header = http_createHeader('Content-Type',...
               'application/json;charset=utf-8') ;

           response = urlread2([self.source_url,self.auth],'POST',body,header) ;

           response = parse_json(response) ;
           response = response{1} ;
        end

        function response = create_inline_source(self,data,params)
            if ~exist('params','var')
                params = containers.Map() ;
            end
            csv_data = self.struct_to_csv(data) ;
            params('data') = csv_data ;
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
        
        function response = list_sources(self,params)
            if ~exist('params','var')
                params = containers.Map() ;
            end
            response = self.list_(self.source_url,params) ;
        end
        
        function response = update_source(self,source,params)
            if ~exist('params','var')
                params = containers.Map() ;
            end
            response = self.update_(source,params) ;
        end
        
        function response = delete_source(self,source)
            response = self.delete_(source) ;
        end
        
        function ok = check_source_id(resource)
            resource = get_res_id(resource) ;
            ok = ~isempty(regexp(resource,self.SOURCE_RE,'once')) ;
        end
        
        %%%%%%%%%%% Datasets %%%%%%%%%%%%
        function response = create_dataset(self,source,params)
            if ~exist('params','var')
                params = containers.Map() ;
            end
                      
            n = 0 ;
            while ~self.source_is_ready(source) 
                pause(self.timeout) ;
                n = n + 1 ;
                if n >= self.n_tries
                    error('Source not available, maximum tries exceeded') ;
                end
            end
                        
            src_res = get_res_id(source) ;
            params('source') = src_res ;
            response = self.urlpost_([self.dataset_url,self.auth],params) ;
        end
        
        function response = get_dataset(self,dataset)
            res = get_res_id(dataset) ;
            url = [self.url,res,self.auth] ;
            response = parse_json(urlread2(url,'GET')) ;
            response = response{1} ;
        end
        
        function ready = dataset_is_ready(self,dataset)
            dataset = self.get_dataset(dataset) ;
            ready = resource_is_ready(dataset) ;
        end
        
        function response = update_dataset(self,dataset,params)
            if ~exist('params','var')
                params = containers.Map() ;
            end
            response = self.update_(dataset,params) ;
        end
        
        function response = delete_dataset(self,dataset)
            response = self.delete_(dataset) ;
        end
        
        function response = list_datasets(self,params)
            if ~exist('params','var')
                params = containers.Map() ;
            end
            response = self.list_(self.dataset_url,params) ;
        end
        
        function response = transform_dataset(self,dataset,params)
            if ~exist('params','var')
                params = containers.Map() ;
            end
            res_id = get_res_id(dataset) ;
            params('origin_dataset') = res_id ;
            response = self.urlpost_([self.dataset_url,self.auth],params) ;   
        end
        
        function response = create_multi_dataset(self,datasets,params)
            if ~exist('params','var')
                params = containers.Map() ;
            end
            if ~iscell(datasets)
                error('origin datasets must be a cell array') ;
            end
            dataset_list = {} ;
            for i = 1:length(datasets)
                dataset_list = [dataset_list, get_res_id(datasets{i})] ;
            end
            params('origin_datasets') = dataset_list ;
            
            response = self.urlpost_([self.dataset_url,self.auth],params) ;
        end
        
        function ok = check_dataset_id(resource)
            resource = get_res_id(resource) ;
            ok = ~isempty(regexp(resource,self.DATASET_RE,'once')) ;
        end
        
        %%%%%%%% Models %%%%%%%%%%%%%
        function response = create_model(self,dataset,params)
            if ~exist('params','var')
                params = containers.Map() ;
            end
            if iscell(dataset)
                    dataset_list = {} ;
                for i = 1:length(dataset)
                    dataset_list = [dataset_list, get_res_id(dataset{i})] ;
                end
                params('datasets') = dataset_list ;
            else
                params('dataset') = get_res_id(dataset) ;
            end
            
            url = [self.model_url,self.auth] ;
            response = self.urlpost_(url,params) ;
        end
        
        function response = get_model(self,model)
            res = get_res_id(model) ;
            url = [self.url,res,self.auth] ;
            response = parse_json(urlread2(url,'GET')) ;
            response = response{1} ;
        end
        
        function response = delete_model(self,model)
            response = self.delete_(model) ;
        end
        
        function response = update_model(self,model,params)
            if ~exist('params','var')
                params = containers.Map() ;
            end
            response = self.update_(model,params) ;
        end
        
        function response = list_models(self,params)
            if ~exist('params','var')
                params = containers.Map() ;
            end
            response = self.list_(self.model_url,params) ;
        end
        
        function ok = check_model_id(resource)
            resource = get_res_id(resource) ;
            ok = ~isempty(regexp(resource,self.MODEL_RE,'once')) ;
        end
        
        %%%%% Ensembles %%%%%%%%%%
        function response = create_ensemble(self,dataset,params)  
            if ~exist('params','var')
                params = containers.Map() ;
            end
            if iscell(dataset)
                dataset_list = {} ;
                for i = 1:length(dataset)
                    dataset_list = [dataset_list, get_res_id(dataset{i})] ;
                end
                params('datasets') = dataset_list ;
            else
                params('dataset') = get_res_id(dataset) ;
            end
            response = self.urlpost_([self.ensemble_url,self.auth],params) ;
        end
        
        function response = get_ensemble(self,ensemble)
            response = self.get_resource_(ensemble) ;
        end
        
        function ready = ensemble_is_ready(self,ensemble)
            e = self.get_ensemble(ensemble) ;
            ready = resource_is_ready(e) ;
        end
        
        function response = update_ensemble(self,ensemble,params)
            if ~exist('params','var')
                params = containers.Map() ;
            end
            response = self.update_(ensemble,params) ;
        end
        
        function response = delete_ensemble(self,ensemble)
            response = self.delete_(ensemble) ;
        end
        
        function response = list_ensembles(self,params)
            if ~exist('params','var')
                params = containers.Map() ;
            end
            response = self.list_(self.ensemble_url,params) ;
        end
        
        function ok = check_ensemble_id(resource)
            resource = get_res_id(resource) ;
            ok = ~isempty(regexp(resource,self.ENSEMBLE_RE,'once')) ;
        end
                
        %%%%%%%%%%%%%%%%% Predictions %%%%%%%%%%%%%
        function response = create_prediction(self,model,input_data,params)
            if ~exist('params','var')
                params = containers.Map() ;
            end
            params('input_data') = input_data ;
            params('model') = get_res_id(model) ;
            response = self.urlpost_([self.prediction_url,self.auth],params) ;
        end
        
        function response = get_prediction(self,prediction)
            response = self.get_resource_(prediction) ;
        end
        
        function ready = prediction_is_ready(self,prediction)
            e = self.get_prediction(prediction) ;
            ready = resource_is_ready(e) ;
        end
        
        function response = update_prediction(self,prediction,params)
            if ~exist('params','var')
                params = containers.Map() ;
            end
            response = self.update_(prediction,params) ;
        end
        
        function response = delete_prediction(self,prediction)
            response = self.delete_(prediction) ;
        end
        
        function response = list_predictions(self,params)
            if ~exist('params','var')
                params = containers.Map() ;
            end
            response = self.list_(self.prediction_url,params) ;
        end
        
        function ok = check_prediction_id(resource)
            resource = get_res_id(resource) ;
            ok = ~isempty(regexp(resource,self.PREDICTION_RE,'once')) ;
        end
        
        %%%%%%%%%%%%%%%%% Batch Predictions %%%%%%%%%%%%%%%
        function response = create_batch_prediction(self,predictor,dataset,params)
            if ~exist('params','var')
                params = containers.Map() ;
            end
            
            % handle multi-datasets
            if iscell(dataset)
                dataset_list = {} ;
                for i = 1:length(dataset)
                    dataset_list = [dataset_list, get_res_id(dataset{i})] ;
                end
                params('datasets') = dataset_list ;
            else
                params('dataset') = get_res_id(dataset) ;
            end
            
            if self.check_model_id(predictor)
                params('model') = get_res_id(predictor) ;
            elseif self.check_ensemble_id(predictor) 
                params('ensemble') = get_res_id(predictor) ;
            else
                error('Pass a valid model or ensemble ID as the predictor') ;
            end
            response = self.urlpost_([self.batch_prediction_url,self.auth],params) ;
        end
        
        function response = get_batch_prediction(self,batch_prediction)
            response = self.get_resource_(batch_prediction) ;
        end
        
        function ready = batch_prediction_is_ready(self,batch_prediction)
            e = self.get_batch_prediction(batch_prediction) ;
            ready = resource_is_ready(e) ;
        end
        
        function response = update_batch_prediction(self,batch_prediction,params)
            if ~exist('params','var')
                params = containers.Map() ;
            end
            response = self.update_(batch_prediction,params) ;
        end
        
        function response = delete_batch_prediction(self,batch_prediction)
            response = self.delete_(batch_prediction) ;
        end
        
        function response = list_batch_predictions(self,params)
            if ~exist('params','var')
                params = containers.Map() ;
            end
            response = self.list_(self.batch_prediction_url,params) ;
        end
        
        function ok = check_batch_prediction_id(resource)
            resource = get_res_id(resource) ;
            ok = ~isempty(regexp(resource,self.BATCHPREDICTION_RE,'once')) ;
        end
        
        %%%%%%%%%%%%%%%%% Evaluations %%%%%%%%%%%%%
        function response = create_evaluation(self,model,dataset,params)
            if ~exist('params','var')
                params = containers.Map() ;
            end
            
            if iscell(dataset)
                dataset_list = {} ;
                for i = 1:length(dataset)
                    dataset_list = [dataset_list, get_res_id(dataset{i})] ;
                end
                params('datasets') = dataset_list ;
            else
                params('dataset') = get_res_id(dataset) ;
            end
            params('model') = get_res_id(model) ;
            response = self.urlpost_([self.evaluation_url,self.auth],params) ;
        end
        
        function response = get_evaluation(self,evaluation)
            response = self.get_resource_(evaluation) ;
        end
        
        function ready = evaluation_is_ready(self,evaluation)
            e = self.get_evaluation(evaluation) ;
            ready = resource_is_ready(e) ;
        end
        
        function response = update_evaluation(self,evaluation,params)
            if ~exist('params','var')
                params = containers.Map() ;
            end
            response = self.update_(evaluation,params) ;
        end
        
        function response = delete_evaluation(self,evaluation)
            response = self.delete_(evaluation) ;
        end
        
        function response = list_evaluations(self,params)
            if ~exist('params','var')
                params = containers.Map() ;
            end
            response = self.list_(self.evaluation_url,params) ;
        end
        
        function ok = check_evaluation_id(resource)
            resource = get_res_id(resource) ;
            ok = ~isempty(regexp(resource,self.EVALUATION_RE,'once')) ;
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
    
    methods (Access = protected)
        function response = get_resource_(self,res)
            res = get_res_id(res) ;
            url = [self.url,res,self.auth] ;
            response = parse_json(urlread2(url,'GET')) ;
            response = response{1} ;
        end
        
        function response = urlpost_(self,url,params)
            body = jsonify(params) ;           
            header = http_createHeader('Content-Type',...
                'application/json;charset=utf-8') ;
            response = urlread2(url,'POST',body,header) ;

            response = parse_json(response) ;
            response = response{1} ; 
        end
        
        function response = update_(self,resource,params)
            resource = get_res_id(resource) ;
            url = [self.url,resource,self.auth] ;
            
            header = http_createHeader('Content-Type',...
                'application/json;charset=utf-8') ;
            body = jsonify(params) ;
            response = parse_json(urlread2(url,'PUT',body,header)) ;
        end
        
        function response = delete_(self,resource)
            resource = get_res_id(resource) ;
            url = [self.url,resource,self.auth] ;
            response = urlread2(url,'DELETE') ;
            if ~isempty(response)
                response = parse_json(response) ;
                response = response{1} ;
            end
        end
        
        function response = list_(self,url,params)
            params = query_string(params) ;
            url = [url,self.auth,';',params] ;
            disp(url)
            response = parse_json(urlread2(url,'GET')) ;
            response = response{1} ;
        end
    end
    
end

%%%%%%%%%%%%%% Utility Functions %%%%%%%%%%%%%%%%%

function res = get_res_id(r)
    if ischar(r)
        res = r ;
    elseif isstruct(r)
        res = r.resource ;
    end
end

function ready = resource_is_ready(res)
   ready = (res.status.code == 5) ;
end

function s = query_string(params)
    s = {} ;
    if isstruct(params)
        if length(params) > 1
            warning('received structure array, using first element') ;
            params = params(1) ;
        end
        names = fieldnames(params)' ;
        for n = names
            val = params.(n{1}) ;
            if isnumeric(val)
                val = num2str(val) ;
            end
            s = [s,n,val] ;
        end
    elseif isa(params,'containers.Map')
        for k = params.keys()
            key = k{1} ;
            val = params(key) ;
            if isnumeric(val)
                val = num2str(val) ;
            end
            s = [s,key,val] ;
        end
    else
        error('parameters should be a structure or a Map') ;
    end
    s = http_paramsToString(s) ;
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
    elseif isa(val,'containers.Map')
        j = map2json(val) ;
    elseif isstruct(val) && length(val) == 1
        j = struct2json(val) ;
    else
        error('Unable to jsonify: ') ;
        disp(val) ;
    end
end

function json = map2json(m)
    % JSON-encode a Map object
    json = '{' ;
    keys = m.keys() ;
    for i = 1:length(keys)
        key = keys{i} ;
        val = jsonify(m(key)) ;
        json = [json,quotify(key),' : ',val] ;
        if (i < length(keys))
            json = [json,','];
        else
            json = [json,'}'] ;
        end
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

