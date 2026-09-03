
import torch
import pandas as pd
import numpy as np
import argparse
import h5py
import sys
import os
from functools import reduce

parser = argparse.ArgumentParser(description='Predict with ctPred')
parser.add_argument('--parameters_file', type=str, help='Path to the JSON parameter file')
parser.add_argument('--individual', type=str, help='Path to the file for metrics. should be a tsv file.')
# parser.add_argument('--epigenome_file', type=str, help='Path to the file for metrics. should be a tsv file.')
parser.add_argument('--output_directory', type=str, help='Output files path')
args = parser.parse_args()

sys.path.append('/beagle3/haky/users/temi/projects/dgtex/src/ctpred')
import ctPred_utils

# read in the parameters file
dt_parameters = pd.read_table(args.parameters_file) #pd.read_table("/beagle3/haky/users/temi/projects/dgtex/files/ctpred.dgtex_models.tsv") #pd.read_table(args.parameters_file)
tup_parameters = list(dt_parameters.itertuples(index=False))
print(f"INFO - Using {len(tup_parameters)} ctPred models")

# tup_parameters = tup_parameters[0:3]

# # read in the individuals files
# dt_individuals = pd.read_table(args.epigenome_file)
# tup_individuals = list(dt_individuals.itertuples(index=False))

# individuals = list()
# for elem in tup_individuals:
#     individuals.append(elem.individual)

# print(f"INFO - Predicting on {len(individuals)} individuals")

# specify the device that you'll use cpu or gpu
# Check for CUDA availability
if torch.cuda.is_available():
    device = torch.device('cuda')
    print("INFO - Using CUDA GPU")
elif torch.backends.mps.is_available(): # For Apple Silicon Macs
    device = torch.device('mps')
    print("INFO - Using Apple MPS")
else:
    device = torch.device('cpu')
    print("INFO - Using CPU")

# parameters = ["/beagle3/haky/users/temi/projects/dgtex/ctpred_models/dgtex_tpm.ctpred_training.Uterus_8_12.ranked_expression_ctPred.pt"]

def generate_batch_n_elems(iterable, n=1):
    l = len(iterable)
    for ndx in range(0, l, n):
        yield iterable[ndx:min(ndx + n, l)]


def load_model(filepath, device = device):
    non_empty_model = ctPred_utils.ctPred()
    non_empty_model.load_state_dict(torch.load(filepath, map_location=device, weights_only=True))
    return non_empty_model

def predict_with_model(model, data, device = device):
    model.to(device)
    model.eval()
    with torch.no_grad():
        data = data.to(device)
        output = model(data)
    return(output)

# with h5py.File('/scratch/midway3/temi/geuvadis_tss_epigenomes/HG00096.tss_epigenomes.hdf5', 'r') as read_File:
#      kk = list(read_File.keys())
#      print(kk)
#      print(read_File["metadata"][:])
#      print(read_File['tss_epigenome']['epigenomes'][:, :].shape) # [:, :, :]

def collect_epigenomes(individual):
    with h5py.File(f"/scratch/midway3/temi/geuvadis_tss_epigenomes/{individual}.tss_epigenomes.hdf5", "r") as read_File:
        epigenomes = read_File['tss_epigenome']['epigenomes'][:, :]
        epigenomes = torch.tensor(epigenomes)
        rownames = [ns.decode("utf-8") for ns in read_File["metadata"][:]] # a list
    return({'rownames':rownames, 'epigenome':epigenomes}) # epigenome is [n_ind, n_loci, 5313]


# individuals_batch = list(generate_batch_n_elems(individuals, n=5))  
# print(f"INFO - Split individuals into {len(individuals_batch)} batches")
#predict_with_model(model_with_parameters.half(), list_epigenomes[0]['epigenome'].half())
# list_predictions[0].shape

# collect all the predictions for individuals 
#list_epigenomes = [collect_epigenomes(individual=indi) for indi in individuals]


individual_data = collect_epigenomes(individual=args.individual)
print(f"INFO - Collected all epigenomes for {args.individual}")
output_predictions = list()
for predictor in tup_parameters:
    model_with_parameters = load_model(predictor.path).half() # hacky should change later
    #for b, indi_batch in enumerate(individuals_batch):
    #print(f"INFO - Collected all epigenomes for {predictor.context}")
    predictions = predict_with_model(model_with_parameters, individual_data['epigenome']).squeeze() 
    output_predictions.append(pd.DataFrame(predictions, index = individual_data['rownames'], columns=[predictor.context]))
    del model_with_parameters

merged_df = reduce(lambda left, right: pd.merge(left, right, left_index=True, right_index=True, how='outer'), output_predictions)
merged_df.to_csv(os.path.join(args.output_directory, f"{args.individual}.ctPred.predictions.tsv"), sep = '\t')
print(f"INFO - Predictions are finished")



    # #mat_predictions = torch.stack(list_predictions, axis = 1)
    # list_names = [epi['rownames'] for epi in list_epigenomes]
    #     print(f"INFO - Number of collected epigenomes for batch {b} is {epigenomes['epigenome'].shape[0]}")
    #     predicted_gene_expression = predict_with_model(model_with_parameters, epigenomes['epigenome']).squeeze().to('cpu')
    #     list_predicted_gene_expression.extend([pd.DataFrame(predicted_gene_expression[i, :], 
    #                                                    index = list(epigenomes['rownames'].values())[i], 
    #                                                     columns=[list(epigenomes['rownames'].keys())[i]]) for i in range(predicted_gene_expression.shape[0])])




    # for predictor in tup_parameters:
    # individual_data = collect_epigenomes(individual=individuals[0])
    # model_with_parameters = load_model(predictor.path).half() # hacky should change later
    # #for b, indi_batch in enumerate(individuals_batch):
    # print(f"INFO - Collected all epigenomes for {predictor.context}")
    # list_predictions = [predict_with_model(model_with_parameters, epi['epigenome']).squeeze() for epi in list_epigenomes]
    # list_dt_predictions = [pd.DataFrame(pp, index = list_epigenomes[i]['rownames'], columns=[individuals[i]]) for i, pp in enumerate(list_predictions)]
    # merged_df = reduce(lambda left, right: pd.merge(left, right, left_index=True, right_index=True, how='outer'), list_dt_predictions)
    # merged_df.to_csv(os.path.join(args.output_directory, f"{predictor.context}.ctPred.predictions.tsv"), sep = '\t')

    # del model_with_parameters