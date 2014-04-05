clear all
close all
clc

%%%%%%%%% API INITIALIZATION %%%%%%%%%%
% The constructor takes some optional parameters:
%   'username': BigML username. Default: value of the environment
%       variable BIGML_USERNAME
%   'apikey': BigML API key. Default: value of env. variable BIGML_API_KEY
%   'devmode': Run in development mode. Default: false
%   'timeout' and 'n_tries': when creation of one resource depends on the 
%       the availablity of another (e.g. models depend on
%       datasets), the API will poll until the required resource is ready.
%       'timeout' is the polling interval in seconds, and 'n_tries' is the
%       maximum number of polls.
api = BigML() ;


%%%%%%%%%%% JSON DATA %%%%%%%%%%%%%%%
% The Matlab binding uses the containers.Map datatype to store all 
% JSON-like objects used in the base RESTful API. Matlab structure are not 
% up to the task because JSON field names are not necessarily valid
% structure field names (e.g. numeric, or contain spaces). 

% Matlab Map objects are derived from Matlab handle objects, so care should 
% be taken when copying them. For convenience, the API contains a static 
% method copy_map() to handle this properly. They also do not support
% nested lookup out of the box. The static method get_nested(map,keys) 
% implements nested lookup, where keys is a cell array of key names.

% All resources created in this demo will be tagged for easy removal
params = containers.Map() ;
params('tags') = {'matlab-api-demo'} ;


% % create source from file
% api.create_local_source('adult.csv') ;
% api.create_local_source('adult.arff') ;
% 
% % create source from URL
% remote_src = api.create_remote_source('https://static.bigml.com/csv/iris.csv',params) ;
% 
% % create inline source
% for i = 1:26
%     data(i).a = i ;
%     data(i).b = i*2 ;
%     data(i).c = [char(65+mod(i,4))] ;
%     data(i).d = i^2 ;
% end 
% inline_params = api.copy_map(params) ;
% inline_params('name') = 'my inline data' ;
% inline_src = api.create_inline_source(data,inline_params) ;
% 
% % update a source
% update_params = containers.Map() ;
% update_params('description') = '[a link](http://www.bigml.com)' ;
% api.update_source(inline_src,update_params) ;
% 
% % delete a source
% api.delete_source(inline_src) ;
% 
% % list sources
% list_params.size__lt = 1024000 ;
% list_params.created__gt = '2014-01-01' ;
% res = api.list_sources() ;
% 
% % create dataset
% dataset = api.create_dataset(remote_src,params) ;
% 
% 
% % update a dataset
% api.update_dataset(dataset,update_params) ;
% 
% % create a model
% model = api.create_model(dataset,params) ;
% 
% % create an ensemble
% ensemble = api.create_ensemble(dataset,params) ;

dataset = 'dataset/533f28df0af5e85b4f010bac' ;
model = 'model/533f28e30af5e85b550356d6' ;

% % create a prediction
% input_data = containers.Map({'petal width'},[0.5]) ;
% pred = api.create_prediction(model,input_data,params) ;
% disp(pred('output')) ;
% 
% % create a batch prediction
% batch = api.create_batch_prediction(model,dataset,params) ;
% while ~api.batch_prediction_is_ready(batch)
%     pause(0.5)
% end
% api.fetch_batch_prediction(batch,'batch.csv') ;

% create an evaluation
evaluation = api.create_evaluation(model,dataset,params) ; 
evaluation = api.wait_ready(evaluation) ;
accuracy = api.get_nested(evaluation,{'result','model','accuracy'}) 
