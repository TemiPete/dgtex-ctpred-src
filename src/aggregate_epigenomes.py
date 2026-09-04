



import argparse, os, sys, multiprocessing
import pandas as pd
import numpy as np

import pathlib
script_dir = pathlib.Path(__file__).parent.resolve() # the directory of the script

parser = argparse.ArgumentParser()
parser.add_argument("--loci_file", type = str, help="the path to the txt files of the loci you want to extract epigenomes on")
parser.add_argument("--reference_epigenome_directory", type = str, help="the path to the per-chromosome hdf5 reference epigenomes")
parser.add_argument("--output_file", type = str, help="the path to the output file for aggregated values", default=None)
parser.add_argument("--use_multiprocessing", action=argparse.BooleanOptionalAction, help="use the pool attribute in multiprocessing", default=False)
parser.add_argument("--pad_bins", type = int, help="the number of bins to pad the center bin with", default=1)

args = parser.parse_args()

sys.path.append(os.path.join(script_dir))

import extract_epigenome

try:
    query_dt = pd.read_table(args.loci_file, header = None, names = ['column_A', 'column_B'])
    query_unique_ids = query_dt.iloc[:, 1].tolist()
    query_loci = query_dt.iloc[:, 0].tolist()
    print(query_loci[0:3])
    print(query_dt.head())
except pd.errors.EmptyDataError as pe:
    raise Exception("ERROR - Loci file is empty")

if args.use_multiprocessing is True:
    print(f'INFO - Using multiprocessing to aggregate epigenomic predictions')
    pool = multiprocessing.Pool(32)
    outputs_list = pool.starmap(extract_epigenome.aggregate_and_collect_epigenome, [(q, qn, args.reference_epigenome_directory, args.pad_bins) for q, qn in zip(query_loci, query_unique_ids)])
    loci = [d['locus'] for d in outputs_list]
    names = [d['name'] for d in outputs_list]
    values = np.array([d['values'] for d in outputs_list])
else:
    outputs_list = [extract_epigenome.aggregate_and_collect_epigenome(q, qn, args.reference_epigenome_directory, pad_bins = args.pad_bins) for q, qn in zip(query_loci, query_unique_ids)]
    loci = [d['locus'] for d in outputs_list]
    names = [d['name'] for d in outputs_list]
    values = np.array([d['values'] for d in outputs_list])

# filter out None types
loci, names, values = [v for v in loci if v is not None], [v for v in names if v is not None], [v for v in values if v is not None]


multi_index = pd.MultiIndex.from_arrays([loci, names], names=['locus', 'name'])
ty = pd.DataFrame(values, index = multi_index)
print(f'INFO - Dimension of collected data is {ty.shape[0]} by {ty.shape[1]}')
ty = ty.reset_index()
column_names = ['locus', 'name']
column_names.extend([f'f_{i}' for i in range(1, 5314)])
#print(len(column_names))
ty = ty.set_axis(column_names, axis=1)
# assert ty.shape[1] == (5313 + 3)

if not args.output_file is None:    
    os.makedirs(os.path.dirname(args.output_file), exist_ok=True)
    ty.to_csv(path_or_buf=args.output_file, index=False, compression='gzip', sep = '\t')
    print(f'INFO - Finished saving data to {args.output_file}')
elif args.output_file is None:
    print(ty.head())
