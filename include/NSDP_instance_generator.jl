function physical_net_mandala(number_nodes::Int64, folder::String) 
    count_node_id = 1
    count_arc_id = 1
    number_arcs = number_nodes*6
    open(joinpath(folder,"auxFile.dat"), "w") do io
            #creating access nodes
            for n in 1:trunc(Int,number_nodes)
                write(io, "node $(count_node_id) node_id $(count_node_id) node_type access longitude $(rand(10:1000)/1.023) latitude $(rand(0:1000)/1.023) coverage_radius $(rand(100:1000)/1.03) ")
                write(io, "ram_capacity $(rand(100:200)) cpu_capacity $(rand(400:400)) storage_capacity  $(rand(100:200)) networking_capacity  $(rand(100:200)) ")
                write(io, "ram_cost $(rand(150:300)) cpu_cost $(rand(600:800)) storage_cost $(rand(1:2)) networking_cost $(rand(1:2)) ue_capacity $(rand(100:200)) availability 0.999 internal_delay 54 node_cost $(rand(100:200))\n\n")
                count_node_id=count_node_id+1
            end

            #creating non-access nodes: agg
            for n in 1:trunc(Int,number_nodes/4)
                write(io, "node $(count_node_id) node_id $(count_node_id) node_type non_access longitude $(rand(10:1000)/1.023) latitude $(rand(0:1000)/1.023) coverage_radius $(rand(100:1000)/1.03) ")
                write(io, "ram_capacity $(rand(900:1100)) cpu_capacity $(rand(480:480)) storage_capacity  $(rand(900:1100)) networking_capacity  $(rand(900:1100)) ")
                write(io, "ram_cost $(rand(150:300)) cpu_cost $(rand(600:800)) storage_cost $(rand(1:2)) networking_cost $(rand(1:2)) ue_capacity $(rand(100:200)) availability 0.999 internal_delay 54 node_cost $(rand(100:200))\n\n")
                count_node_id=count_node_id+1
            end

            #creating non-access nodes : core
            for n in 1:trunc(Int,number_nodes/4)
                write(io, "node $(count_node_id) node_id $(count_node_id) node_type non_access longitude $(rand(10:1000)/1.023) latitude $(rand(0:1000)/1.023) coverage_radius $(rand(100:1000)/1.03) ")
                write(io, "ram_capacity $(rand(900:1100)) cpu_capacity $(rand(560:560)) storage_capacity  $(rand(900:1100)) networking_capacity  $(rand(900:1100)) ")
                write(io, "ram_cost $(rand(150:300)) cpu_cost $(rand(600:800)) storage_cost $(rand(1:2)) networking_cost $(rand(1:2)) ue_capacity $(rand(100:200)) availability 0.999 internal_delay 54 node_cost $(rand(100:200))\n\n")
                count_node_id=count_node_id+1   
            end

            #creating app nodes
            for n in 1:trunc(Int,number_nodes/8)
                write(io, "node $(count_node_id) node_id $(count_node_id) node_type app longitude $(rand(10:1000)/1.023) latitude $(rand(0:1000)/1.023) coverage_radius $(rand(100:1000)/1.03) ")
                write(io, "ram_capacity 0.0 cpu_capacity 0.0 storage_capacity  0.0 networking_capacity  0.0 ")
                write(io, "ram_cost $(rand(150:300)) cpu_cost $(rand(600:800)) storage_cost $(rand(1:2)) networking_cost $(rand(1:2)) ue_capacity $(rand(100:200)) availability 0.999 internal_delay 54 node_cost $(rand(100:200))\n\n")
                count_node_id=count_node_id+1   
            end


            adj_matrix = Matrix{Bool}(undef, trunc(Int,number_nodes+number_nodes/4+number_nodes/4+number_nodes/8), trunc(Int,number_nodes+number_nodes/4+number_nodes/4+number_nodes/8))
            for n in 1:trunc(Int,number_nodes+number_nodes/4+number_nodes/4+number_nodes/8), m in 1:trunc(Int,number_nodes+number_nodes/4+number_nodes/4+number_nodes/8)
                adj_matrix[n,m] = false
            end

            incoming_arcs= Vector{Int16}()
            for n in 1:trunc(Int,number_nodes+number_nodes/4+number_nodes/4+number_nodes/2)
                push!(incoming_arcs,0)
            end

            #arcs btw access nodes and aggregation nodes  
            for n in 1:number_nodes

              source = trunc(Int,n)
              for  num_arc in 1:2    
                test = false
                tries = 0    
                target = trunc(Int,rand(number_nodes+1:number_nodes+number_nodes/4))
                while test==false
                    if adj_matrix[source,target] == false && incoming_arcs[target]<8
                        test = true 
                        incoming_arcs[target] = incoming_arcs[target]+1
                        adj_matrix[source,target] = true
                        adj_matrix[target,source] = true 
                        latency = round(rand(50:100)/1000, digits=2)
                        bandwidth = 202.5
                        write(io, "arc    $(count_arc_id)    edge_id $(count_arc_id) source $(trunc(Int,source)) target $(trunc(Int,target)) type fiber delay $(latency) max_bandwidth $(bandwidth) availability 0.999 cost 0.1\n\n")
                        count_arc_id=count_arc_id+1
                        write(io, "arc    $(count_arc_id)    edge_id $(count_arc_id) source $(trunc(Int,target)) target $(trunc(Int,source)) type fiber delay  $(latency)  max_bandwidth $(bandwidth) availability 0.999 cost 0.1\n\n")
                        count_arc_id=count_arc_id+1

                    elseif tries >=10000
                          test = true  

                    else
                        target = trunc(Int,rand(number_nodes+1:number_nodes+number_nodes/4))
                        tries=tries+1            

                    end #end if-else
                end#end while
            end#end for  num_arc in 1:2 
        end #end of  for n in number_nodes

        #arcs btw aggregation nodes and core nodes 
        for n in number_nodes+1:number_nodes+number_nodes/4

          source = trunc(Int,n)
          for  num_arc in 1:2    
                test = false
                target = trunc(Int,rand(number_nodes+number_nodes/4+1:number_nodes+number_nodes/2))
                tries = 0        
                while test==false
                    if adj_matrix[source,target] == false && target !=source && incoming_arcs[target]<2
                        test = true 
                        incoming_arcs[target] = incoming_arcs[target]+1
                        adj_matrix[source,target] = true
                        adj_matrix[target,source] = true 
                        latency = round(rand(200:300)/1000, digits=2)
                        bandwidth = 202.5*2
                        write(io, "arc    $(count_arc_id)    edge_id $(count_arc_id) source $(trunc(Int,source)) target $(trunc(Int,target)) type fiber delay $(latency) max_bandwidth $(bandwidth) availability 0.999 cost 0.1\n\n")
                        count_arc_id=count_arc_id+1
                        write(io, "arc    $(count_arc_id)    edge_id $(count_arc_id) source $(trunc(Int,target)) target $(trunc(Int,source)) type fiber delay  $(latency)  max_bandwidth $(bandwidth) availability 0.999 cost 0.1\n\n")
                        count_arc_id=count_arc_id+1

                    elseif tries >=10000
                          test = true          

                    else
                        target = trunc(Int,rand(number_nodes+number_nodes/4+1:number_nodes+number_nodes/2))
                        tries = tries + 1            

                    end #end if-else
                end#end while
            end#end for  num_arc in 1:2 
        end #end of  for n in number_nodes+1:number_nodes+number_nodes/4 


       #arcs btw core nodes and app nodes
        for n in number_nodes+number_nodes/4+1:number_nodes+number_nodes/2
              source = trunc(Int,n)
              for  num_arc in 1:2    
                test = false
                target = trunc(Int,rand(number_nodes+number_nodes/2+1:number_nodes+number_nodes/2+number_nodes/8))
                tries = 0        
                while test==false
                    if adj_matrix[source,target] == false && target !=source && incoming_arcs[target]<4
                        test = true 
                        incoming_arcs[target] = incoming_arcs[target]+1
                        adj_matrix[source,target] = true
                        adj_matrix[target,source] = true 
                        latency = round(rand(400:600)/1000, digits=2)
                        bandwidth = 202.5*3
                        write(io, "arc    $(count_arc_id)    edge_id $(count_arc_id) source $(trunc(Int,source)) target $(trunc(Int,target)) type fiber delay $(latency) max_bandwidth $(bandwidth) availability 0.999 cost 0.1\n\n")
                        count_arc_id=count_arc_id+1
                        write(io, "arc    $(count_arc_id)    edge_id $(count_arc_id) source $(trunc(Int,target)) target $(trunc(Int,source)) type fiber delay  $(latency)  max_bandwidth $(bandwidth) availability 0.999 cost 0.1\n\n")
                        count_arc_id=count_arc_id+1

                    elseif tries >=10000
                          test = true          

                    else
                        target = trunc(Int,rand(number_nodes+number_nodes/2+1:number_nodes+number_nodes/2+number_nodes/8))
                        tries = tries + 1            

                    end #end if-else
                end#end while
            end#end for  num_arc in 1:2 
        end #end of  for n in number_nodes+number_nodes/4+1:number_nodes+number_nodes/2
                                
    end# closing io file
    open(joinpath(folder,"auxFile.dat"), "r") do ioo
    open(joinpath(folder,"my_phyNet.dat"), "w") do io
        write(io, "number_of_nodes $(count_node_id-1)\n")
        write(io, "number_of_arcs $(count_arc_id-1)\n")
        write(io, "node_capacity_types 4 storage_capacity networking_capacity ram_capacity cpu_capacity\n\n")          
        write(io,ioo)
    end end
                                                          
end



function slice_requests_generator(number_nodes::Int64, folder::String, number_commodities::Int64, number_slices::Int64,test::Int64)
    dus = Vector{Int8}()
    for s in 1:number_slices
        open(joinpath(folder,"commodities_$(s)_test$(test).dat"), "w") do io
            write(io, "number_of_commodities $(trunc(Int,number_commodities))\n\n")
            if length(dus)==8
                 dus = Vector{Int8}()
            end
            ver = true
            while ver ==true
                du = trunc(Int,rand(1:number_nodes))
                if (du âˆˆ dus) == false
                    push!(dus,du) 
                    ver = false  
                end
            end
                    
            if s <= 8 
                write(io, "commodity_id 1 origin_node $(dus[length(dus)]) target_node $(trunc(Int,rand(number_nodes+number_nodes/4+number_nodes/4+1:number_nodes+number_nodes/4+number_nodes/4+number_nodes/8))) volume_of_data $(6*30).0\n")
            elseif s > 8 && s <= 16 
                write(io, "commodity_id 1 origin_node $(dus[length(dus)]) target_node $(trunc(Int,rand(number_nodes+number_nodes/4+number_nodes/4+1:number_nodes+number_nodes/4+number_nodes/4+number_nodes/8))) volume_of_data $(6*1).0\n")

            elseif s > 16 && s <= 24 
                write(io, "commodity_id 1 origin_node $(dus[length(dus)]) target_node $(trunc(Int,rand(number_nodes+number_nodes/4+number_nodes/4+1:number_nodes+number_nodes/4+number_nodes/4+number_nodes/8))) volume_of_data $(0.18*25)\n")
            elseif s > 24  
                write(io, "commodity_id 1 origin_node $(dus[length(dus)]) target_node $(trunc(Int,rand(number_nodes+number_nodes/4+number_nodes/4+1:number_nodes+number_nodes/4+number_nodes/4+number_nodes/8))) volume_of_data $(6*2).0\n")
            end

        end
    end
end

