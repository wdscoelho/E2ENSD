
##############################################################################
# Created by: Wesley DA SILVA COELHO
##############################################################################
#This file contains the main script for NSDP model execution
#: https://hal.archives-ouvertes.fr/hal-02448028v3


##############################################################################
#                   INCLUDE PACKAGES
##############################################################################
using NBInclude #Package to include personal files",
using JuMP #Mathematical programming package : allows us to define the MILP",
using LightGraphs #Package to construct simple graphs",
using MetaGraphs #Package to construct complex graphs",


# path to some folders
input_folder = "../inputs/"
include_folder = "../include/"
result_folder = "../Results/" 



#including files
@nbinclude(joinpath(include_folder,"NSDP_instance_generator.ipynb"))# code creator for 5GNSD instances
@nbinclude(joinpath(include_folder,"NSDP_structures.ipynb")) # our data structures 
@nbinclude(joinpath(include_folder,"NSDP_solver.ipynb")) # impementation of our model 
@nbinclude(joinpath(include_folder,"NSDP_instance_reader.ipynb"))# file responsible for parseing new NSDP instances



#Defining instance size
number_DUs = 16 #for mandala topology, it means total size = 13/8*number_DUs     
number_request_per_slice=8
number_slices=4

#creating instances
physical_net_mandala(number_DUs,input_folder) 
slice_requests_generator(number_DUs, input_folder, number_request_per_slice, number_slices)

#sharing policies to be tested 
sharing_policies = ["flatSharing","hard","sharedCP","sharedDP","partialCP","partialDP"]
# split options: .... 7=flex
split_settings = [1,2,3,4,5,6,7] 

#creating files and their headres to store the final solutions
#see the header (on write function) to know the information on each file 
open(joinpath(result_folder,"load_on_nodes.csv"), "w") do finalNodeLoad
    write(finalNodeLoad,"nodeID;type;policy;split;load\n")
end

open(joinpath(result_folder,"load_on_arcs.csv"), "w") do finalArcLoad
    write(finalArcLoad,"arcID;type;policy;split;load\n") 
end

open(joinpath(result_folder,"final_statistics.csv"), "w") do finalStatistics 
    write(finalStatistics,"instance_name;policy;split;Objective_value;NFSintalled;disNFS;centNFS;nodes;activeNodes;acitiveNodeRatio;totalNodeCapacity;totalNodeLoad;avNodeLoad;mostLoadedNode;arc;activeArcs;acitiveArcRatio;totalArcCapacity;totalArcLoad;avArcLoad;mostLoadedArc\n")
end

for policy in sharing_policies

    #getting all proprities needed to represent the instance
    my_instance = get_Instance(input_folder,policy)

    for split in split_settings  
        #creating model
        model = create_NSDP_model(my_instance, "option_$(split)")
        #calling solver 
        solve_NSDP_model(model,policy,split)
        #getting and saving final solution and information
        get_solution(model,my_instance,result_folder,split,policy)
    end 

end

