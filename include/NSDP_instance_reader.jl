
############################################################################################

# Thesis title: Modeling and Optimization for 5G Network Design
# Ph.D. student: Wesley DA SILVA COELHO
# Thesis Director : Stefano SECCI (Conservatoire National des Arts et MÃ©tiers - CEDRIC)
# Thesis Supervisors : Amal BENHAMICHE and Nancy PERROT (Orange Labs)
############################################################################################
#This file contains the main script to parse instances

#                   INCLUDE PACKAGES"
using DataStructures
using NBInclude
using LightGraphs 
using MetaGraphs
include("NSDP_structures.jl")

function get_Instance_pre(input_folder::String,mp::String)
    
   #Here, we get all proprities needed to represent the instance
        set,anf,cnf = get_VNFs(joinpath(input_folder,"VNFs_instance_1.dat"))
        instance = Instance(set,
                            get_physical_network(joinpath(input_folder,"my_phyNetITC.dat")),
                            get_NS_requests(joinpath(input_folder,"instance_$(mp)_pre.dat")))

        instance.VNF_connection = get_VNFs_To_Connect(instance)
        instance.number_of_AN_based_NFs = anf
        instance.number_of_CN_based_NFs = cnf
        instance.maxLatencyBetweenFunctions = get_latency_between_functions(joinpath(input_folder,"latency_btw_functions_1.dat"))
        number_commodities = 0

        instance.number_of_NFs = 4
        instance.slice_beta = get_slice_beta(joinpath(input_folder,"slice_beta.dat"))
        instance.slice_rho = get_slice_rho(joinpath(input_folder,"slice_rho.dat"))
        instance.maxLatencyBetweenDU_NFS1 = 0.25
        
        return instance
    
end

function get_Instance(input_folder::String,mp::String,test::Int64)
    
   #Here, we get all proprities needed to represent the instance
        set,anf,cnf = get_VNFs(joinpath(input_folder,"VNFs_instance_1.dat"))
        instance = Instance(set,
                            get_physical_network(joinpath(input_folder,"my_phyNetITC.dat")),
                            get_NS_requests(joinpath(input_folder,"instance_$(mp).dat"),test))

        instance.VNF_connection = get_VNFs_To_Connect(instance)
        instance.number_of_AN_based_NFs = anf
        instance.number_of_CN_based_NFs = cnf
        instance.maxLatencyBetweenFunctions = get_latency_between_functions(joinpath(input_folder,"latency_btw_functions_1.dat"))
        number_commodities = 0
        for s in 1:length(instance.setSlices)
            number_commodities+=length(instance.setSlices[s].set_commodities)
        end
        instance.number_of_NFs = 4
        
        return instance
    
end

function get_NS_requests(file::String,test::Int64) 
    #Auxiliar variables
    setSlices = Vector{SliceRequest}()
   # We open a text file found on the recieved path "file::String"
    open(file) do file
        
        #we read line by line
        for ln in eachline(file)

            #Here, we storage each word / number in a position of aux_string vector
            aux_string = split(ln)
            
            #error treatment: if it is a line with nothing written, we return to the first isntruction of this loop
            if length(aux_string) == 0
                continue #going dic=rectly to the first line of the loop
            end
            
            #getting number of slice_requests 
            if aux_string[1] == "number_of_requests" 
                number_of_requests = Meta.parse(aux_string[2]) # Meta.parse tries to convert strings into a most suitable type
            
            #getting slice requests and their attributes
            elseif aux_string[1]  == "slice_request" 
                VNFs_to_install_instance_name, aux_set_VNFs_to_install = get_VNFs_to_install(joinpath(input_folder,Meta.parse(aux_string[16])))    
                
                # adding its attributes
                push!(setSlices, SliceRequest(parse(Int8,aux_string[4]),parse(Int16,aux_string[10]),
                                         parse(Float16,aux_string[12]),VNFs_to_install_instance_name,Meta.parse(aux_string[18]),
                                         Meta.parse(aux_string[20]), get_VNF_sharing(Meta.parse(aux_string[20])),
                                        aux_set_VNFs_to_install,get_commodities(Meta.parse(aux_string[22]),test), parse(Float16,aux_string[24]),get_node_sharing(Meta.parse(aux_string[26]))))
           
                end# end of conditions   
               
        end#end for - we have read all lines from file
     
    end#closing file
    return setSlices 

end # end of function get_NS_requests

function get_slice_beta(file::String)
    #auxiliar variables
    number_of_slices = 0
    aux_Matrix01 = Vector{ Vector{Int8} } 
    aux_Matrix_return = []
   
    open(file) do file
  
        #we read line by line
        for ln in eachline(file)

            #Here, we storage each word / number in a position of aux_string vector
            aux_string = split(ln)

            #error treatment: if it is a line with nothing written or with ";", we return to the first isntruction of this loop
            if length(aux_string) == 0
                continue #going directly to the first line of the loop
            end
            
            #getting number of VNFs 
            if aux_string[1] == "number_of_slices" 
                number_of_slices = parse(Int64,aux_string[2]) # Meta.parse tries to convert strings into a most suitable type

            else
                #we add its attributes
                aux_vector = Array{Int8,1}(undef, number_of_slices)          

                for (n, f) in enumerate(aux_string)
                    aux_vector[n] = parse(Int8,f)
                end  
                 push!(aux_Matrix_return,aux_vector)       

            end# end of conditions   

        end#end for - we have read all lines from file   

    end#closing file
    
    return aux_Matrix_return 

end
    
    
function get_slice_rho(file::String)
    #auxiliar variables
    number_of_dus = 0
    aux_Matrix01 = Vector{ Vector{Int8} } 
    aux_Matrix_return = []
   
    open(file) do file
  
        #we read line by line
        for ln in eachline(file)

            #Here, we storage each word / number in a position of aux_string vector
            aux_string = split(ln)

            #error treatment: if it is a line with nothing written or with ";", we return to the first isntruction of this loop
            if length(aux_string) == 0
                continue #going directly to the first line of the loop
            end
            
            #getting number of VNFs 
            if aux_string[1] == "number_of_dus" 
                number_of_dus = parse(Int64,aux_string[2]) # Meta.parse tries to convert strings into a most suitable type

            else
                #we add its attributes
                aux_vector = Array{Int8,1}(undef, number_of_dus)          

                for (n, f) in enumerate(aux_string)
                    aux_vector[n] = parse(Int8,f)
                end  
                 push!(aux_Matrix_return,aux_vector)       

            end# end of conditions   

        end#end for - we have read all lines from file   

    end#closing file
    
    return aux_Matrix_return 

end

function get_node_sharing(file::String)
    #auxiliar variables
    my_vector = Vector{Int8}()

    # We open a text file found on the recieved path "file::String"
    open(file) do file
  
        #we read line by line
        for ln in eachline(file)

            #Here, we storage each word / number in a position of aux_string vector
            aux_string = split(ln)
            for n in 1:length(aux_string)
                push!(my_vector, parse(Int8, aux_string[n]))
            end
        end
    end
    return my_vector
end

function get_VNF_sharing(file::String) 
    
    #auxiliar variables
    number_of_slices = 0
    number_VNFs = 0
    aux_Matrix1 = Vector{ Vector{Int8} } 
    aux_Matrix = aux_Matrix1(undef,0)
    aux_dic = Dict()    
   
    # We open a text file found on the recieved path "file::String"
    open(file) do file
  
        #we read line by line
        for ln in eachline(file)

            #Here, we storage each word / number in a position of aux_string vector
            aux_string = split(ln)

            #error treatment: if it is a line with nothing written or with ";", we return to the first isntruction of this loop
            if length(aux_string) == 0
                continue #going directly to the first line of the loop
            end
            
            if aux_string[1]  == ";" 
                    aux_dic["$(length(aux_dic)+1)"] = aux_Matrix
                    aux_Matrix = aux_Matrix1(undef,0)
                    continue #going directly to the first line of the loop
            end

            #getting number of VNFs and Slices 
            if aux_string[1] == "number_of_VNFs" 
                number_VNFs = parse(Int64,aux_string[2]) # Meta.parse tries to convert strings into a most suitable type

            elseif aux_string[1] == "number_of_slices" 
                number_of_slices = parse(Int8,aux_string[2]) # Meta.parse tries to convert strings into a most suitable type

            else
                #creating Sharing Matrix
                aux_vector = Array{Bool,1}(undef, number_VNFs)          

                for (n, f) in enumerate(aux_string)
                    aux_vector[n] = parse(Int8,f)
                end  
                 push!(aux_Matrix,aux_vector)       

            end# end of conditions   

        end#end for - we have read all lines from file   

    end#closing file
    
    return aux_dic 

end # end of function get_VNF_sharing

function get_physical_network(file::String) 

    physical_network = MetaDiGraph() # It is this graph that we return in the end of this function. We use "Meta" to have several attributes on each node and each edge.
    set_prop!(physical_network, :type, "all")
   # We open a text file found on the recieved path "file::String"
    open(file) do file
        
        #we read line by line
        for ln in eachline(file)
            
            #Here, we storage each word / number in a position of aux_string vector
            aux_string = split(ln)
            
            #error treatment: if it is a line with nothing written, we return to the first instruction of this loop
            if length(aux_string) == 0
                continue #going directly to the first line of the loop
            end
            
            #getting number of nodes, set it as a attributes of physical_network and add this number of nodes to the graph
            if aux_string[1] == "number_of_nodes" 
                MetaGraphs.set_prop!(physical_network, :number_nodes, Meta.parse(aux_string[2])) # Meta.parse tries to convert strings into a most suitable type
                MetaGraphs.add_vertices!(physical_network, Meta.parse(aux_string[2]))
                
            #getting number of edges set it as a attributes of physical_network graph    
            elseif aux_string[1]  == "number_of_arcs" 
                MetaGraphs.set_prop!(physical_network, :number_of_arcs, Meta.parse(aux_string[2]))
            
            #getting nodes and their attributes
            elseif aux_string[1]  == "node" 
                
                #we add its attributes
                MetaGraphs.set_props!(physical_network, Meta.parse(aux_string[2]), Dict(:node_id =>Meta.parse(aux_string[4]), :node_type =>aux_string[6] , :longitude =>Meta.parse(aux_string[8]), :latitude =>Meta.parse(aux_string[10]), :coverage_radius =>Meta.parse(aux_string[12]), :ram_capacity =>Meta.parse(aux_string[14]), :cpu_capacity =>Meta.parse(aux_string[16]), :storage_capacity =>Meta.parse(aux_string[18]), :networking_capacity =>Meta.parse(aux_string[20]), :ram_cost =>Meta.parse(aux_string[22]), :cpu_cost =>Meta.parse(aux_string[24]), :storage_cost =>Meta.parse(aux_string[26]), :networking_cost =>Meta.parse(aux_string[28]), :ue_capacity =>Meta.parse(aux_string[30]), :availability =>Meta.parse(aux_string[32]), :internal_delay =>Meta.parse(aux_string[34]), :cost_node =>Meta.parse(aux_string[36]) ))
           
            
            #getting edges and their attributes. Here, we can add an edge and its attributes with the same function
            elseif aux_string[1]  == "arc"            
                MetaGraphs.add_edge!(physical_network, Meta.parse(aux_string[6]), Meta.parse(aux_string[8]), Dict(:edge_id=>Meta.parse(aux_string[4]), :source =>Meta.parse(aux_string[6]), :target =>Meta.parse(aux_string[8]), :type =>aux_string[10], :delay =>Meta.parse(aux_string[12]), :max_bandwidth =>Meta.parse(aux_string[14]), :availability=>Meta.parse(aux_string[16]), :cost =>Meta.parse(aux_string[18])))
                 
            elseif aux_string[1]  == "node_capacity_types"
                aux_vec = Vector{Symbol}()                
                MetaGraphs.set_prop!(physical_network, :number_node_capacity_types, parse(Int8,aux_string[2]))              
                for i in 1:parse(Int8,aux_string[2])
                    push!(aux_vec, Meta.parse(aux_string[i+2]))
                end
                MetaGraphs.set_prop!(physical_network, :node_capacity_types, aux_vec)              
                
         end# end of conditions   
                
        end#end for - we have read all lines from file
     
        end#closing file
    
    return physical_network 

end # end of function get_physical_network


function get_VNFs(file::String) 

    #Auxiliar variables
    number_VNFs = 0
    number_of_AN_based_NFs = 0
    number_of_CN_based_NFs = 0
    set_of_VNFs = Vector{VNF}()
    
   # We open a text file found on the recieved path "file::String"
    open(file) do file
        
        #we read line by line
        for ln in eachline(file)

            #Here, we storage each word / number in a position of aux_string vector
            aux_string = split(ln)
            
            #error treatment: if it is a line with nothing written, we return to the first isntruction of this loop
            if length(aux_string) == 0
                continue #going dic=rectly to the first line of the loop
            end
            
            #getting number of VNFs 
            if aux_string[1] == "number_of_VNFs" 
                number_VNFs = Meta.parse(aux_string[2]) # Meta.parse tries to convert strings into a most suitable type
            
            elseif aux_string[1]  == "number_of_AN-based_NFs" 
                number_of_AN_based_NFs =  parse(Int64,aux_string[2])
            
            elseif aux_string[1]  == "number_of_CN-based_NFs" 
                number_of_CN_based_NFs = parse(Int64,aux_string[2])
                        
            #getting VNFs and their attributes
            elseif aux_string[1]  == "VNF" 
                
                #we add its attributes
                t = Meta.parse(aux_string[6])
                aux_vector = Array{Float16,1}(undef, number_VNFs)    
                for i in 1:number_VNFs 
                    aux_vector[i] = Meta.parse(aux_string[21+i])
                end
                push!(set_of_VNFs, VNF(Meta.parse(aux_string[4]),Meta.parse(aux_string[6]),Meta.parse(aux_string[8]),Meta.parse(aux_string[10]),
                                         Meta.parse(aux_string[12]),Meta.parse(aux_string[14]),Meta.parse(aux_string[16]), parse(Float16,aux_string[18]),aux_vector,parse(Int64,aux_string[20])))
            end# end of conditions   
                
        end#end for - we have read all lines from file
     
    end#closing file
    
    return set_of_VNFs,number_of_AN_based_NFs,number_of_CN_based_NFs 

end # end of function get_VNFs

function get_latency_between_functions(file::String)
    
    number_of_functions = 0
    aux_Matrix1 = Vector{ Vector{Float16} } 
    #aux_Matrix_return =  aux_Matrix01(undef,0)
    aux_Matrix_return = []
    # We open a text file found on the recieved path "file::String"
   
    open(file) do file
  
        #we read line by line
        for ln in eachline(file)

            #Here, we storage each word / number in a position of aux_string vector
            aux_string = split(ln)

            #error treatment: if it is a line with nothing written or with ";", we return to the first isntruction of this loop
            if length(aux_string) == 0
                continue #going directly to the first line of the loop
            end
            
            #getting number of VNFs 
            if aux_string[1] == "number_of_functions" 
                number_of_functions = parse(Int64,aux_string[2]) # Meta.parse tries to convert strings into a most suitable type

            else
                #we add its attributes
                aux_vector = Array{Float16,1}(undef, number_of_functions)          

                for (n, f) in enumerate(aux_string)
                    aux_vector[n] = parse(Float16,f)
                end  
                 push!(aux_Matrix_return,aux_vector)       

            end# end of conditions   

        end#end for - we have read all lines from file   

    end#closing file
    
    return aux_Matrix_return 

end

function get_VNFs_to_install(file::String) 

    set_VNF_to_install_instance = ""
    number_of_VNFs_to_install = 0
       
    # We open a text file found on the recieved path "file::String"
    open(file) do file
  
        #we read line by line
        for ln in eachline(file)

            #Here, we storage each word / number in a position of aux_string vector
            aux_string = split(ln)

            #error treatment: if it is a line with nothing written or with ";", we return to the first isntruction of this loop
            if length(aux_string) == 0
                continue #going directly to the first line of the loop
            end
            
            #getting micro areas
            if aux_string[1] == "set_VNF_to_install" 
                set_VNF_to_install_instance = Meta.parse(aux_string[2]) # Meta.parse tries to convert strings into a most suitable type

            elseif aux_string[1] == "number_of_VNFs_to_install" 
                number_of_VNFs_to_install = parse(Int16,aux_string[2]) # Meta.parse tries to convert strings into a most suitable type

            else
                #we add its attributes
                aux_vector = Array{Int16,1}(undef, number_of_VNFs_to_install)          

                for (n, f) in enumerate(aux_string)
                    aux_vector[n] = parse(Int16,f)
                end  
                        
                return set_VNF_to_install_instance , aux_vector 
                        
            end# end of conditions   

        end#end for - we have read all lines from file   

    end#closing file
    

end # end of function get_VNF_sharing

function get_VNFs_To_Connect(instance::Instance)
    
    #auxiliar variables
    number_VNFs = 0
    aux_Matrix1 = Vector{ Vector{Bool} } 
    aux_Matrix = aux_Matrix1(undef,0)
    aux_dic = Dict()    
    
    # We open a text file found on the recieved path "file::String"
    for each_slice in instance.setSlices
       file = joinpath(input_folder, each_slice.VNFs_To_Connect)

        open(file) do file
  
            #we read line by line
            for ln in eachline(file)

                #Here, we storage each word / number in a position of aux_string vector
                aux_string = split(ln)

                #error treatment: if it is a line with nothing written or with ";", we return to the first isntruction of this loop
                if length(aux_string) == 0
                    continue #going directly to the first line of the loop
                end

                #getting number of VNFs 
                if aux_string[1] == "number_of_VNFs" 
                    number_VNFs = parse(Int64,aux_string[2]) # Meta.parse tries to convert strings into a most suitable type

                else
                    #creating Conection Matrix
                    aux_vector = Array{Bool,1}(undef, number_VNFs)          

                    for (n, f) in enumerate(aux_string)
                        aux_vector[n] = parse(Bool,f)
                    end  
                     push!(aux_Matrix,aux_vector)  

                end# end of conditions   

            end#end for - we have read all lines from file   
             
            aux_dic["$(each_slice.id)"] = aux_Matrix
            aux_Matrix = aux_Matrix1(undef,0) 
       
        end#closing file
    end#end for each slice
   
    return aux_dic 
end#end of function


function get_commodities(file1::String,test::Int64) 
    
    #auxiliar variables
    aux_vector = Vector{Dict}()
    number_of_commodities = Int16
    aux = split(file1,".dat")
    file = "$(aux[1])_test$(test).dat"
   # We open a text file found on the recieved path "file::String"
    open(file) do file
        
        #we read line by line
        for ln in eachline(file)

            #Here, we storage each word / number in a position of aux_string vector
            aux_string = split(ln)
            
            #error treatment: if it is a line with nothing written, we return to the first isntruction of this loop
            if length(aux_string) == 0
                continue #going dic=rectly to the first line of the loop
            end
            
            #getting number of commodities 
            if aux_string[1] == "number_of_commodities" 
                number_of_commodities = Meta.parse(aux_string[2]) # Meta.parse tries to convert strings into a most suitable type
           
            #getting commodities and their attributes
            elseif aux_string[1]  == "commodity_id" 
                
                #we add its attributes
                aux_dict = Dict()
                aux_dict["commodity_id"] = parse(Int64, aux_string[2])
                aux_dict["origin_node"] = parse(Int64, aux_string[4])
                aux_dict["target_node"] = parse(Int64, aux_string[6])
                aux_dict["volume_of_data"] = parse(Float16, aux_string[8])
                
                push!(aux_vector, aux_dict)
            end# end of conditions   
        end#end for - we have read all lines from file
     
    end#closing file
    
    return aux_vector 

end # end of function get_VNF_sharing
