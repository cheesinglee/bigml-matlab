clear all
close all
clc
% initialize API
api = BigML() ;

% tag all resources created in this demo
params.tags = {'matlab-api-demo'} ;

% % create source from file
% api.create_local_source('adult.csv') ;
% api.create_local_source('adult.arff') ;
% 
% % create source from URL
% remote_src = api.create_remote_source('https://static.bigml.com/csv/iris.csv',params) ;

% create inline source
for i = 1:26
    data(i).a = i ;
    data(i).b = i*2 ;
    data(i).c = [char(65+mod(i,4))] ;
    data(i).d = i^2 ;
end 
inline_params = params ;
inline_params.name = 'my inline data' ;
inline_src = api.create_inline_source(data,inline_params) ;

% create dataset
params.objective_field = struct('id','000002') ;
dataset = api.create_dataset(inline_src,params) ;
