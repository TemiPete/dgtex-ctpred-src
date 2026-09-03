
import torch
import pandas as pd
import numpy as np
import argparse
import h5py
import os
import multiprocessing

parser = argparse.ArgumentParser(description='Collect epigenomes')
parser.add_argument('--epigenome_file', type=str, help='Path to the file for metrics. should be a tsv file.')
parser.add_argument('--output_directory', type=str, help='Path to the file for metrics. should be a tsv file.')
parser.add_argument('--number_of_processors', type = int, default=32)
args = parser.parse_args()

def generate_batch_n_elems(iterable, n=1):
    l = len(iterable)
    for ndx in range(0, l, n):
        yield iterable[ndx:min(ndx + n, l)]


db_folder = "/scratch/midway3/temi/geuvadis_tss_epigenomes"

for indi in individuals:
    new_dbfile = os.path.join(db_folder, f"{indi}.tss_epigenomes.hdf5")
    old_dbfile = f"/beagle3/haky/users/charles/project/singleXcanDL/Dataset/Geuvadis/Enformer_output_4bins/{indi}.h5"
    with h5py.File(f"/beagle3/haky/users/charles/project/singleXcanDL/Dataset/Geuvadis/Enformer_output_4bins/{indi}.h5", "r") as oldF:
        # count number of groups you expect
        group_count = 0
        loci = list(oldF.keys())[0:5]
        group_count = len(loci)
        print(f"INFO - Found {group_count} loci for {indi}")
        # for key in oldF.keys():
        #     if isinstance(oldF[key], h5py.Group):
        #         group_count += 1
        with h5py.File(new_dbfile, "w") as newF:
            # create one dataset
            merged_groups = newF.create_group('tss_epigenome')
            merged_data = merged_groups.create_dataset("epigenomes", (group_count, 5313), dtype='f2')
            try:
                for i, locus in enumerate(loci):
                    epi = oldF[locus][:].mean(axis = 0).T #(4, 1, 5313) -> (5353, ) -> (,5313)
                    merged_data[i, :] = epi
            except Exception as e:
                    print(f"The loop breaks at index {i} with the following error: {e}")
                    continue
                

def collect_epigenomes(individuals):
    output = list()
    rownames = dict()
    for indi in individuals:
        with h5py.File(f"/beagle3/haky/users/charles/project/singleXcanDL/Dataset/Geuvadis/Enformer_output_4bins/{indi}.h5", "r") as f:
            loci_keys = list(f.keys())
            epigenomes = [f[key][:].mean(axis = 0) for key in loci_keys]
            epigenomes = torch.tensor(np.stack(epigenomes, axis=0))
            output.append(epigenomes)
            rownames[indi] = loci_keys
    output = torch.stack(output, axis = 0)
    return({'rownames':rownames, 'epigenome':output}) # epigenome is [n_ind, n_loci, 5313]

# read in the individuals files
dt_individuals = pd.read_table(args.epigenome_file) #pd.read_table("/beagle3/haky/users/temi/projects/dgtex/files/geuvadis_individuals.epigenomes.tsv") 
tup_individuals = list(dt_individuals.itertuples(index=False))

individuals = list()
for elem in tup_individuals:
    individuals.append(elem.individual)

print(f"INFO - Collecting for {len(individuals)} individuals")
individuals_batch = list(generate_batch_n_elems(individuals, n=10))   # so there are n in each batch
print(f"INFO - Split individuals into {len(individuals_batch)} batches")

pool = multiprocessing.Pool(args.number_of_processors)
collected_epigenomes_list = pool.map(collect_epigenomes, individuals_batch) #[{rownames: [...], epigenome: np.array[...]}, ...]
# make each one a dataframe
# individual_epigenomes = dict()
for epigenomes_list in collected_epigenomes_list:
    dd = {list(epigenomes_list['rownames'].keys())[i]: pd.DataFrame(epigenomes_list['epigenome'][i, :], 
                                                       index = list(epigenomes_list['rownames'].values())[i],
                                                       columns=[f"f_{i+1}" for i in range(epigenomes_list['epigenome'][i, :].shape[1])]) for i in range(epigenomes_list['epigenome'].shape[0])}
    for key, value in dd.items():
        value.to_csv(os.path.join('/beagle3/haky/users/temi/projects/dgtex/data/geuvadis_epigenomes', f"{key}.epigenomes.tsv"), sep = '\t')
        
    
# merged_df = reduce(lambda left, right: pd.merge(left, right, left_index=True, right_index=True, how='outer'), list_predicted_gene_expression)

# epigenomes_list['epigenome'][1, :].shape


 
                                                        # columns=[list(epigenomes_list['rownames'].keys())[i]]

# list_predicted_gene_expression.extend([pd.DataFrame(epigenomes_list['epigenome'][i, :], 
#                                                        index = list(epigenomes_list['rownames'].values())[i],
#                                                        columns=[f"f_{i+1}" for i in range(epigenomes_list['epigenome'][i, :].shape[1])]) for i in range(epigenomes_list['epigenome'].shape[0])])

# for predictor in tup_parameters:
#     list_predicted_gene_expression = list()
#     model_with_parameters = load_model(predictor.path)
#     for b, indi_batch in enumerate(individuals_batch):
#         epigenomes = collect_epigenomes(individuals=indi_batch)
#         print(f"INFO - Number of collected epigenomes for batch {b} is {epigenomes['epigenome'].shape[0]}")
#         predicted_gene_expression = predict_with_model(model_with_parameters, epigenomes['epigenome']).squeeze().to('cpu')
#         list_predicted_gene_expression.extend([pd.DataFrame(predicted_gene_expression[i, :], 
#                                                        index = list(epigenomes['rownames'].values())[i], 
#                                                         columns=[list(epigenomes['rownames'].keys())[i]]) for i in range(predicted_gene_expression.shape[0])])
#     merged_df = reduce(lambda left, right: pd.merge(left, right, left_index=True, right_index=True, how='outer'), list_predicted_gene_expression)
#     merged_df.to_csv(os.path.join(args.output_directory, f"{predictor.context}.ctPred.predictions.tsv"), sep = '\t')

#     del model_with_parameters

# print(f"INFO - Predictions are finished")



