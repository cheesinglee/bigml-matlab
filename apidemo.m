clear all
close all
clc

addpath('util') ;

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


disp('create source from file')
api.create_local_source('data/adult.csv',params) ;
api.create_local_source('data/adult.arff',params) ;

disp('create source from URL')
remote_src = api.create_remote_source('https://static.bigml.com/csv/iris.csv',params) ;

disp('create inline source')
for i = 1:26
    data(i).a = i ;
    data(i).b = i*2 ;
    data(i).c = [char(65+mod(i,4))] ;
    data(i).d = i^2 ;
end 
inline_params = api.copy_map(params) ;
inline_params('name') = 'my inline data' ;
inline_src = api.create_inline_source(data,inline_params) ;

 
disp('update a source')
update_params = containers.Map() ;
update_params('description') = '[a link](http://www.bigml.com)' ;
api.update_source(inline_src,update_params) ;


disp('list sources')
list_params.size__lt = 1024000 ;
list_params.created__gt = '2014-01-01' ;
res = api.list_sources() ;
obj = res('objects') ;
for i = 1:length(obj)
    o = obj{i} ;
    disp([o('resource') '    ' o('name')])
end

disp('create dataset')
dataset = api.create_dataset(remote_src,params) ;

% update a dataset
api.update_dataset(dataset,update_params) ;

disp('create a model')
model = api.create_model(dataset,params) ;

disp('create an ensemble')
ensemble = api.create_ensemble(dataset,params) ;

disp('create a prediction')
input_data = containers.Map({'petal width'},[0.5]) ;
pred = api.create_prediction(model,input_data,params) ;
disp(pred('output')) ;

disp('create a batch prediction')
batch = api.create_batch_prediction(model,dataset,params) ;
while ~api.batch_prediction_is_ready(batch)
    pause(0.5)
end
api.fetch_batch_prediction(batch,'batch.csv') ;

disp('create an evaluation')
evaluation = api.create_evaluation(model,dataset,params) ; 
evaluation = api.wait_ready(evaluation) ;
accuracy = api.get_nested(evaluation,{'result','model','accuracy'}) ;
disp(['accuracy = ' num2str(accuracy)])

% uncomment the following code to automatically delete everything created
% by this demo

disp('cleaning up')
query.tags__in = 'matlab-api-demo' ;
% also acceptable:
% query = containers.Map ;
% query('tags__in') = 'matlab-api-demo' ;

sources = api.list_sources(query) ;
objects = sources('objects') ;
for i = 1:length(objects)
    o = objects{i} ;
    api.delete_source(o) ;
end

datasets = api.list_datasets(query) ;
objects = datasets('objects') ;
for i = 1:length(objects)
    o = objects{i} ;
    api.delete_dataset(o) ;
end

models = api.list_models(query) ;
objects = models('objects') ;
for i = 1:length(objects)
    o = objects{i} ;
    api.delete_model(o) ;
end

ensembles = api.list_ensembles(query) ;
objects = ensembles('objects') ;
for i = 1:length(objects)
    o = objects{i} ;
    api.delete_ensemble(o) ;
end

predictions = api.list_predictions(query) ;
objects = predictions('objects') ;
for i = 1:length(objects)
    o = objects{i} ;
    api.delete_prediction(o) ;
end

batch_predictions = api.list_batch_predictions(query) ;
objects = batch_predictions('objects') ;
for i = 1:length(objects)
    o = objects{i} ;
    api.delete_batch_prediction(o) ;
end

evaluations = api.list_evaluations(query) ;
objects = evaluations('objects') ;
for i = 1:length(objects)
    o = objects{i} ;
    api.delete_evaluation(o) ;
end