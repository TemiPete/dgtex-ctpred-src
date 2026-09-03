
import pandas as pd
import numpy as np
import argparse
import h5py
import os

parser = argparse.ArgumentParser(description='Collect epigenomes')
parser.add_argument('--individual', type=str, help='Path to the file for metrics. should be a tsv file.')
# parser.add_argument('--output_directory', type=str, help='Path to the file for metrics. should be a tsv file.')
# parser.add_argument('--number_of_processors', type = int, default=32)
args = parser.parse_args()

# # read in the individuals files
# dt_individuals = pd.read_table(args.epigenome_file) #pd.read_table("/beagle3/haky/users/temi/projects/dgtex/files/geuvadis_individuals.epigenomes.tsv") 
# tup_individuals = list(dt_individuals.itertuples(index=False))

# individuals = list()
# for elem in tup_individuals:
#     individuals.append(elem.individual)

# individuals = individuals[0:2]

print(f"INFO - Collecting for {args.individual}")

db_folder = "/scratch/midway3/temi/geuvadis_tss_epigenomes"

new_dbfile = os.path.join(db_folder, f"{args.individual}.tss_epigenomes.hdf5")
old_dbfile = f"/beagle3/haky/users/charles/project/singleXcanDL/Dataset/Geuvadis/Enformer_output_4bins/{args.individual}.h5"
with h5py.File(f"/beagle3/haky/users/charles/project/singleXcanDL/Dataset/Geuvadis/Enformer_output_4bins/{args.individual}.h5", "r") as oldF:
    # count number of groups you expect
    group_count = 0
    loci = list(oldF.keys())
    group_count = len(loci)
    print(f"INFO - Found {group_count} loci for {args.individual}")
    # for key in oldF.keys():
    #     if isinstance(oldF[key], h5py.Group):
    #         group_count += 1
    with h5py.File(new_dbfile, "w") as newF:
        # create one dataset
        merged_groups = newF.create_group('tss_epigenome')
        merged_data = merged_groups.create_dataset("epigenomes", (group_count, 5313), dtype='f2')

        # save the metadata
        metadata_type = h5py.special_dtype(vlen=str)
        metadata_loci = np.array(loci, dtype = metadata_type)
        newF.create_dataset('metadata', data=metadata_loci)
        # loci_metadata = merged_groups.create_dataset("loci", shape=(len(loci),), dtype=h5py.string_dtype())
        # loci_metadata[:] = loci
        try:
            for i, locus in enumerate(loci):
                epi = oldF[locus][:].mean(axis = 0).T #(4, 1, 5313) -> (5353, ) -> (,5313)
                merged_data[i, :] = epi
        except Exception as e:
                print(f"The loop breaks at index {i} with the following error: {e}")



# with h5py.File('/scratch/midway3/temi/geuvadis_tss_epigenomes/HG00096.tss_epigenomes.hdf5', 'r') as read_File:
#      kk = list(read_File.keys())
#      print(kk)
#      print(read_File["metadata"][:])
#      print(read_File['tss_epigenome']['epigenomes'][:, :].shape) # [:, :, :]
