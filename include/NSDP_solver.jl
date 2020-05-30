
using JuMP,CPLEX,MathProgBase
using NBInclude,GraphIO
using LightGraphs, MetaGraphs

function get_model_info(instance::Instance,my_model::Model)
    println("Number of variables = $(MathProgBase.numvar(my_model))")
    println("Number of constraints = $(MathProgBase.numlinconstr(my_model))")
end

function create_NSDP_model(instance::Instance, split_::String)
    my_model = Model(solver=CplexSolver())

    #-------------------------Variables--------------------
    @variable(my_model, z[s in 1:length(instance.setSlices),f in 1:instance.number_of_AN_based_NFs],Bin)
    @variable(my_model, x[s in 1:length(instance.setSlices),f in 1:length(instance.set_VNFs), m in 1:instance.number_of_NFs, u in 1: props(instance.physical_network)[:number_nodes]], Bin)
    @variable(my_model, w[s in 1:length(instance.setSlices),f in 1:length(instance.set_VNFs), m in 1:instance.number_of_NFs, u in 1: props(instance.physical_network)[:number_nodes]] >= 0)
    @variable(my_model, y[f in 1:length(instance.set_VNFs), m in 1:instance.number_of_NFs, u in 1: props(instance.physical_network)[:number_nodes]] >=0, Int)
    @variable(my_model, gamma[s in 1:length(instance.setSlices), k in 1:length(instance.setSlices[s].set_commodities), a in 1: props(instance.physical_network)[:number_of_arcs],f in 1:length(instance.set_VNFs)+1, g in 1:length(instance.set_VNFs)+1], Bin)
   

    #---------------------------------------------
    #-----------------Additional Constraints-----------------
    # additional proposed split where all data-plane NFS are installed locally.
    if split_ == "option_1"
        for s in 1:length(instance.setSlices)
            @constraint(my_model, z[s,5]==0)
        end
    
    #additional proposed split where only the NFS5 is installed at the CU. This split simulates a scenario where all RAN NFSs are installed locally while 
    #the data-plane NFs from core network are installed centrally
    elseif split_ == "option_2"
        for s in 1:length(instance.setSlices)
            @constraint(my_model, z[s,5]==1)
            @constraint(my_model, z[s,4]==0)
        end
    
    # for each slice, only NFSs 4 and 5 are installed centrally.  
    elseif split_ == "option_3"
         for s in 1:length(instance.setSlices)
            @constraint(my_model, z[s,4]==1)
             @constraint(my_model, z[s,3]==0)
        end       

    # or each slice, NFS~3, NFS~4, and NFS~5 are installed at the centrally while NFS~1 and NFS~2 are distributed.
    elseif split_ == "option_4"
        for s in 1:length(instance.setSlices)
             @constraint(my_model, z[s,3]==1)
             @constraint(my_model, z[s,2]==0)
        end          
    
    #Split Option 5 & for each slice, only the NFSs~1 is installed locally  
    elseif split_ == "option_5"
        for s in 1:length(instance.setSlices)
             @constraint(my_model, z[s,2]==1)
             @constraint(my_model, z[s,1]==0)
        end             
        
    # additional proposed split where all data-plane NFS are installed centrally
    elseif split_ == "option_6"
        for s in 1:length(instance.setSlices)
             @constraint(my_model, z[s,1]==1)
        end         
    end
    
    #---------------------------------------------
    # SPLIT SELECTION
    #---------------------------------------------
    for s in 1:length(instance.setSlices),  f in 1:(instance.number_of_AN_based_NFs-1)
        @constraint(my_model, z[s,f]<=z[s,f+1])
    end
    
   
    #---------------------------------------------
    # DIMENSIONING - CP NFSs
    #---------------------------------------------
    for s in 1:length(instance.setSlices),  f in (instance.number_of_AN_based_NFs+1):(instance.number_of_CN_based_NFs+instance.number_of_AN_based_NFs),u in 1: props(instance.physical_network)[:number_nodes],n in 1:instance.number_of_NFs
        if props(instance.physical_network, u)[:node_type] == "non_access"
            @constraint(my_model, w[s,f,n,u]  == instance.set_VNFs[f].dataVolPerUE*instance.setSlices[s].TotalAmountUE*x[s,f,n,u] /instance.set_VNFs[f].treatment_capacity)
        end
    end 
    #---------------------------------------------
    # DIMENSIONING - DISTRIBUTED DP NFSs
    #---------------------------------------------
     for s in 1:length(instance.setSlices),  k in instance.setSlices[s].set_commodities, f in 1:instance.number_of_AN_based_NFs,n in 1:instance.number_of_NFs
         if f!=1
            @constraint(my_model, w[s,f,n,k["origin_node"]]  == instance.set_VNFs[f-1].compression*k["volume_of_data"]*x[s,f,n,k["origin_node"]]/instance.set_VNFs[f].treatment_capacity)
    
        else
            @constraint(my_model, w[s,f,n,k["origin_node"]] == k["volume_of_data"]*x[s,f,n,k["origin_node"]]/instance.set_VNFs[f].treatment_capacity)
        end
    end
    #---------------------------------------------
    # DIMENSIONING - CENTRALIZED DP NFSs
    #---------------------------------------------
     for s in 1:length(instance.setSlices),  f in 1:instance.number_of_AN_based_NFs, u in 1: props(instance.physical_network)[:number_nodes],n in 1:instance.number_of_NFs
        if props(instance.physical_network, u)[:node_type] == "non_access" && f!=1
            @constraint(my_model, w[s,f,n,u] == instance.setSlices[s].set_VNFs_to_install[f]*(sum(instance.set_VNFs[f-1].compression*k["volume_of_data"] for k in instance.setSlices[s].set_commodities)*x[s,f,n,u])/instance.set_VNFs[f].treatment_capacity)                
        elseif props(instance.physical_network, u)[:node_type] == "non_access" && f==1
            @constraint(my_model, w[s,f,n,u] ==  instance.setSlices[s].set_VNFs_to_install[f]*(sum(k["volume_of_data"] for k in instance.setSlices[s].set_commodities)*x[s,f,n,u])/instance.set_VNFs[f].treatment_capacity)                
        end
    end

                                                
    #---------------------------------------------
    # PLACEMENT - DISTRIBUTED DP NFSs
    #---------------------------------------------
    for s in 1:length(instance.setSlices),  f in 1:instance.number_of_AN_based_NFs, k in instance.setSlices[s].set_commodities
          @constraint(my_model, sum(x[s,f,m,k["origin_node"]] for m in 1:instance.number_of_NFs)== instance.setSlices[s].set_VNFs_to_install[f]*(1 - z[s,f]))
    end
            
  
    #---------------------------------------------
    # PLACEMENT - CENTRALIZED DP NFSs
    #---------------------------------------------
     for s in 1:length(instance.setSlices),  f in 1:instance.number_of_AN_based_NFs
        expression = zero(AffExpr)
        for u in 1: props(instance.physical_network)[:number_nodes]
            if  props(instance.physical_network, u)[:node_type] == "non_access"
                expression+= sum(x[s,f,m,u] for m in 1:instance.number_of_NFs)
            end

        end
        @constraint(my_model, expression == instance.setSlices[s].set_VNFs_to_install[f]*z[s,f])            
    end
                
    #---------------------------------------------
    # PLACEMENT - CP NFSs
    #---------------------------------------------
     for s in 1:length(instance.setSlices),  f in (1+instance.number_of_AN_based_NFs):(instance.number_of_AN_based_NFs + instance.number_of_CN_based_NFs)
        expression = zero(AffExpr)
        for u in 1: props(instance.physical_network)[:number_nodes]
        
            if props(instance.physical_network,u)[:node_type]=="non_access"
                expression+= sum(x[s,f,m,u] for m in 1:instance.number_of_NFs)
            end
         end
                
        @constraint(my_model, expression == instance.setSlices[s].set_VNFs_to_install[f])            
     end

    
    #---------------------------------------------
    # VIRTUAL ISOLATION
    #---------------------------------------------
    for s in 1:length(instance.setSlices),t in 1:length(instance.setSlices)
        if  s!=t
            for u in 1: props(instance.physical_network)[:number_nodes],  m in 1:instance.number_of_NFs,  f in 1:length(instance.set_VNFs),g in 1:length(instance.set_VNFs)            
                @constraint(my_model, x[s,f,m,u] + x[t,g,m,u]  <= 1 + instance.setSlices[s].VNF_sharing["$(t)"][f][g]*instance.setSlices[t].VNF_sharing["$(s)"][g][f])  
             end
        end
    end

    #---------------------------------------------
    # PACKING
    #--------------------------------------------
    for f in 1:length(instance.set_VNFs), m in 1:instance.number_of_NFs, u in 1: props(instance.physical_network)[:number_nodes]
        @constraint(my_model, sum(w[s,f,m,u] for s in 1:length(instance.setSlices))  <= y[f,m,u])
    end
            
    for s in 1:length(instance.setSlices),
        t in 1:length(instance.setSlices),
        f in 1:length(instance.set_VNFs), 
        g in 1:length(instance.set_VNFs),
        u in 1: props(instance.physical_network)[:number_nodes],
        v in 1: props(instance.physical_network)[:number_nodes],
        n in 1:instance.number_of_NFs
       
        if u!=v
            @constraint(my_model, x[s,f,n,u] + x[t,g,n,v] <=1)
        end
        
    end       
    #---------------------------------------------
    # NODE CAPACITY
    #---------------------------------------------
    for u in 1: props(instance.physical_network)[:number_nodes]
        @constraint(my_model,  sum(instance.set_VNFs[f].cpu_request*y[f,m,u] for f in 1:length(instance.set_VNFs), m in 1:instance.number_of_NFs) <= props(instance.physical_network,u)[:cpu_capacity])
     end
                 
                      
    
    #---------------------------------------------
    # FLOW - BETWEEN CENTRALIZED DP NFSs
    #---------------------------------------------
    for s in 1:length(instance.setSlices), k in 1:length(instance.setSlices[s].set_commodities), f in 1:(instance.number_of_AN_based_NFs-1),u in 1: props(instance.physical_network)[:number_nodes]
            
        if props(instance.physical_network, u)[:node_type] == "non_access"
            ingoing = zero(AffExpr)
            outgoing = zero(AffExpr)
            conttt=0
            for a in edges(instance.physical_network)
                if src(a) == u
                   outgoing+= gamma[s,k,get_prop(instance.physical_network,a,:edge_id),f,f+1]
                end
                if dst(a) == u
                   ingoing+= gamma[s,k,get_prop(instance.physical_network,a,:edge_id),f,f+1] 
                end
            end
                @constraint(my_model, outgoing - ingoing == sum(x[s,f,m,u] for m in 1:instance.number_of_NFs) -sum(x[s,f+1,m,u] for m in 1:instance.number_of_NFs))
            
        end    
    end
                
    #---------------------------------------------
    # FLOW - BETWEEN DP NFSs ON THE SPLIT
    #---------------------------------------------
    for s in 1:length(instance.setSlices), k in 1:length(instance.setSlices[s].set_commodities), f in 1:instance.number_of_AN_based_NFs-1
        u=instance.setSlices[s].set_commodities[k]["origin_node"]
        outgoing = zero(AffExpr)
        for a in edges(instance.physical_network)
            if src(a) == u
               outgoing+= gamma[s,k,get_prop(instance.physical_network,a,:edge_id),f,f+1]
            end
        end
        @constraint(my_model, outgoing  == z[s,f+1] - z[s,f])
    end
    #---------------------------------------------------
    # FLOW - BETWEEN  NFSs AND TARGET AND ORIGIN NODES
    #------------------------------------------------------
    for s in 1:length(instance.setSlices), k in 1:length(instance.setSlices[s].set_commodities), u in 1: props(instance.physical_network)[:number_nodes]
            
        ingoing_target= zero(AffExpr)
        outgoing_target = zero(AffExpr)
        ingoing_origin = zero(AffExpr)
        outgoing_origin = zero(AffExpr)
        conttt=0
        for a in edges(instance.physical_network)
            if src(a) == u
               outgoing_target+= gamma[s,k,get_prop(instance.physical_network,a,:edge_id),instance.number_of_AN_based_NFs,length(instance.set_VNFs)+1]
               outgoing_origin+= gamma[s,k,get_prop(instance.physical_network,a,:edge_id),length(instance.set_VNFs)+1,1]
            end
            if dst(a) == u
                ingoing_target+= gamma[s,k,get_prop(instance.physical_network,a,:edge_id),instance.number_of_AN_based_NFs,length(instance.set_VNFs)+1] 
                ingoing_origin+= gamma[s,k,get_prop(instance.physical_network,a,:edge_id),length(instance.set_VNFs)+1,1] 
            end
        end
        if  u==instance.setSlices[s].set_commodities[k]["target_node"]
            @constraint(my_model, outgoing_target - ingoing_target == -1)
        end
        if  u==instance.setSlices[s].set_commodities[k]["origin_node"]
            @constraint(my_model, outgoing_target - ingoing_target == 1-z[s,instance.number_of_AN_based_NFs])
            @constraint(my_model, outgoing_origin - ingoing_origin == z[s,1])

        end
        if   u!=instance.setSlices[s].set_commodities[k]["origin_node"] &&  props(instance.physical_network, u)[:node_type] == "access"
            @constraint(my_model, outgoing_target - ingoing_target == 0)
            @constraint(my_model, outgoing_origin - ingoing_origin == 0)
        end
        if    props(instance.physical_network, u)[:node_type] == "non_access"
            @constraint(my_model, outgoing_target - ingoing_target == sum(x[s,instance.number_of_AN_based_NFs,m,u] for m in 1:instance.number_of_NFs))
            @constraint(my_model, outgoing_origin - ingoing_origin == -sum(x[s,1,m,u] for m in 1:instance.number_of_NFs))
        end

    end

    #---------------------------------------------
    # FLOW - BETWEEN CP NFSs
    #---------------------------------------------
    for s in 1:length(instance.setSlices),  f in (instance.number_of_AN_based_NFs+1):(instance.number_of_CN_based_NFs+instance.number_of_AN_based_NFs),g in (instance.number_of_AN_based_NFs+1):(instance.number_of_CN_based_NFs+instance.number_of_AN_based_NFs),u in 1: props(instance.physical_network)[:number_nodes]
        if f!=g && instance.VNF_connection["$(s)"][f][g] == true && instance.setSlices[s].set_VNFs_to_install[g] == true && instance.setSlices[s].set_VNFs_to_install[f] == true
            ingoing = zero(AffExpr)
            outgoing = zero(AffExpr)
            for a in edges(instance.physical_network)
              if src(a) == u
                   outgoing+= gamma[s,1,get_prop(instance.physical_network,a,:edge_id),f,g]          
                end
                if dst(a) == u
                   ingoing+= gamma[s,1,get_prop(instance.physical_network,a,:edge_id),f,g]          
                end
            end
            @constraint(my_model, outgoing - ingoing == sum(x[s,f,m,u] for m in 1:instance.number_of_NFs) - sum(x[s,g,m,u] for m in 1:instance.number_of_NFs))
        end
    end
                
    #---------------------------------------------
    # FLOW - BETWEEN DP AND CP NFSs
    #---------------------------------------------               
    for s in 1:length(instance.setSlices), k in 1:length(instance.setSlices[s].set_commodities), f in (instance.number_of_AN_based_NFs+1):(instance.number_of_CN_based_NFs+instance.number_of_AN_based_NFs),g in 1:instance.number_of_AN_based_NFs,u in 1: props(instance.physical_network)[:number_nodes]
        if instance.VNF_connection["$(s)"][f][g] == true && instance.setSlices[s].set_VNFs_to_install[g] == true && instance.setSlices[s].set_VNFs_to_install[f] == true
            ingoing = zero(AffExpr)
            outgoing = zero(AffExpr)
            for a in edges(instance.physical_network)
              if src(a) == u
                   outgoing+= gamma[s,k,get_prop(instance.physical_network,a,:edge_id),f,g]          
                end
                if dst(a) == u
                   ingoing+= gamma[s,k,get_prop(instance.physical_network,a,:edge_id),f,g]          
                end
            end
            if props(instance.physical_network, u)[:node_type] == "non_access"           
                @constraint(my_model, outgoing - ingoing == sum(x[s,f,m,u] for m in 1:instance.number_of_NFs) - sum(x[s,g,m,u] for m in 1:instance.number_of_NFs))

            elseif props(instance.physical_network, u)[:node_type] == "access" && props(instance.physical_network, u)[:node_id] ==  instance.setSlices[s].set_commodities[k]["origin_node"]           
                @constraint(my_model, outgoing - ingoing == z[s,g]-1)
            else
               @constraint(my_model, outgoing - ingoing == 0)
            end
        end
    end        

                    
  for s in 1:length(instance.setSlices), k in 1:length(instance.setSlices[s].set_commodities),f in 1:instance.number_of_AN_based_NFs,g in (instance.number_of_AN_based_NFs+1):instance.number_of_AN_based_NFs+instance.number_of_CN_based_NFs,u in 1: props(instance.physical_network)[:number_nodes]
        if instance.VNF_connection["$(s)"][f][g] == true && instance.setSlices[s].set_VNFs_to_install[g] == true && instance.setSlices[s].set_VNFs_to_install[f] == true
            ingoing = zero(AffExpr)
            outgoing = zero(AffExpr)
            for a in edges(instance.physical_network)
              if src(a) == u
                   outgoing+= gamma[s,k,get_prop(instance.physical_network,a,:edge_id),f,g]          
                end
                if dst(a) == u
                   ingoing+= gamma[s,k,get_prop(instance.physical_network,a,:edge_id),f,g]          
                end
            end
            if props(instance.physical_network, u)[:node_type] == "non_access"           
                @constraint(my_model, outgoing - ingoing == sum(x[s,f,m,u] for m in 1:instance.number_of_NFs) - sum(x[s,g,m,u] for m in 1:instance.number_of_NFs))
            
            elseif props(instance.physical_network, u)[:node_type] == "access" && props(instance.physical_network, u)[:node_id] ==  instance.setSlices[s].set_commodities[k]["origin_node"]           
                 @constraint(my_model, outgoing - ingoing == 1 - z[s,f])
            else
                 @constraint(my_model, outgoing - ingoing == 0)            
            end
        end
    end         
        
    #---------------------------------------------
    #  E2E DP LATENCY
    #---------------------------------------------
    for s in 1:length(instance.setSlices), k in 1:length(instance.setSlices[s].set_commodities)
        delay_path = zero(AffExpr)
        for a in edges(instance.physical_network)
            delay_path+= sum(get_prop(instance.physical_network,a,:delay) *gamma[s,k,get_prop(instance.physical_network,a,:edge_id),f,f+1] for f in 1:(instance.number_of_AN_based_NFs-1))
            delay_path+= get_prop(instance.physical_network,a,:delay) * (gamma[s,k,get_prop(instance.physical_network,a,:edge_id),length(instance.set_VNFs)+1,1] +gamma[s,k,get_prop(instance.physical_network,a,:edge_id),instance.number_of_AN_based_NFs,length(instance.set_VNFs)+1])
        end
        @constraint(my_model, delay_path <= instance.setSlices[s].maxLatencyDataLayer)  
    end
     #
    #---------------------------------------------
    # LATENCY BTW DP NFSs
    #---------------------------------------------
    for s in 1:length(instance.setSlices), k in 1:length(instance.setSlices[s].set_commodities),f in 1:(instance.number_of_AN_based_NFs-1)
        delay_path = zero(AffExpr)
        for a in edges(instance.physical_network)            
                delay_path+= get_prop(instance.physical_network,a,:delay) * gamma[s,k,get_prop(instance.physical_network,a,:edge_id),f,f+1]
          end
            
        @constraint(my_model, delay_path <= instance.maxLatencyBetweenFunctions[f][f+1])  

    end
    #---------------------------------------------
    # LATENCY BTW DU and NFS1
    #---------------------------------------------                                           
    for s in 1:length(instance.setSlices), k in 1:length(instance.setSlices[s].set_commodities)
        delay_path = zero(AffExpr)
        for a in edges(instance.physical_network)            
                delay_path+= get_prop(instance.physical_network,a,:delay) * gamma[s,k,get_prop(instance.physical_network,a,:edge_id),length(instance.set_VNFs)+1,1]
          end
            
         #@constraint(my_model, delay_path <= instance.maxLatencyBetweenDU_NFS1)  

    end

    #---------------------------------------------
    # LATENCY BTW CP NFSs
    #---------------------------------------------
    for s in 1:length(instance.setSlices),  f in (1+instance.number_of_AN_based_NFs):(instance.number_of_CN_based_NFs+instance.number_of_AN_based_NFs),g in 1:(instance.number_of_CN_based_NFs+instance.number_of_AN_based_NFs)
        if instance.VNF_connection["$(s)"][f][g] == true
            delay_path = zero(AffExpr)
            for a in edges(instance.physical_network)             
                delay_path+= get_prop(instance.physical_network,a,:delay) * gamma[s,1,get_prop(instance.physical_network,a,:edge_id),f,g] 
            end
           @constraint(my_model, delay_path <= instance.maxLatencyBetweenFunctions[f][g])  
        end
    end
                                
    #---------------------------------------------
    # LATENCY BTW CP AND DP NFSs
    #---------------------------------------------
    for s in 1:length(instance.setSlices), k in 1:length(instance.setSlices[s].set_commodities), f in 1:(instance.number_of_CN_based_NFs+instance.number_of_AN_based_NFs),g in 1:(instance.number_of_CN_based_NFs+instance.number_of_AN_based_NFs)
        if instance.VNF_connection["$(s)"][f][g] == true
            delay_path = zero(AffExpr)
            for a in edges(instance.physical_network)             
                delay_path+= get_prop(instance.physical_network,a,:delay) * gamma[s,k,get_prop(instance.physical_network,a,:edge_id),f,g] 
            end
            @constraint(my_model, delay_path <= instance.maxLatencyBetweenFunctions[f][g])  
        end
    end

   
    #---------------------------------------------
    # LINK CAPACITY
                                                
    #---------------------------------------------
    for a in edges(instance.physical_network)           
        sum_gamma = zero(AffExpr)            
        for s in 1:length(instance.setSlices), k in 1:length(instance.setSlices[s].set_commodities)
            sum_gamma+=gamma[s,k,get_prop(instance.physical_network,a,:edge_id),length(instance.set_VNFs)+1,1]*instance.setSlices[s].set_commodities[k]["volume_of_data"]
            sum_gamma+=gamma[s,k,get_prop(instance.physical_network,a,:edge_id),instance.number_of_AN_based_NFs,length(instance.set_VNFs)+1]*instance.setSlices[s].set_commodities[k]["volume_of_data"]*instance.set_VNFs[instance.number_of_AN_based_NFs].compression
            for f in 1:(instance.number_of_AN_based_NFs+instance.number_of_CN_based_NFs), g in 1:(instance.number_of_AN_based_NFs+instance.number_of_CN_based_NFs)
                if f!=g 
                    if f <= instance.number_of_AN_based_NFs && g <= instance.number_of_AN_based_NFs && f==g-1                      
                        sum_gamma+=gamma[s,k,get_prop(instance.physical_network,a,:edge_id),f,g]*instance.setSlices[s].set_commodities[k]["volume_of_data"]*instance.set_VNFs[f].compression
                    end                            
                    if f>instance.number_of_AN_based_NFs && g>instance.number_of_AN_based_NFs
                        sum_gamma+=gamma[s,1,get_prop(instance.physical_network,a,:edge_id),f,g]*instance.set_VNFs[f].amount_of_traffic_sent_to_g[g]*(instance.setSlices[s].TotalAmountUE/length(instance.setSlices[s].set_commodities))
                    elseif f>instance.number_of_AN_based_NFs && g<=instance.number_of_AN_based_NFs
                        sum_gamma+=gamma[s,k,get_prop(instance.physical_network,a,:edge_id),f,g]*instance.set_VNFs[f].amount_of_traffic_sent_to_g[g]*(instance.setSlices[s].TotalAmountUE/length(instance.setSlices[s].set_commodities))
                    elseif f<=instance.number_of_AN_based_NFs && g>instance.number_of_AN_based_NFs
                        sum_gamma+=gamma[s,k,get_prop(instance.physical_network,a,:edge_id),f,g]*instance.set_VNFs[f].amount_of_traffic_sent_to_g[g]*(instance.setSlices[s].TotalAmountUE/length(instance.setSlices[s].set_commodities))

                    end
                end

            end
        end
        @constraint(my_model, sum_gamma <= get_prop(instance.physical_network,a,:max_bandwidth))
    end

    #-------------------------- objective-----------------------------------------
    @objective(my_model, Min ,  0.1*sum(gamma[s,k,a,f,g] for s in 1:length(instance.setSlices),k in 1:length(instance.setSlices[s].set_commodities),a in 1: props(instance.physical_network)[:number_of_arcs],f in 1:length(instance.set_VNFs)+1, g in 1:length(instance.set_VNFs)+1) + 
                                sum(y[f,m,u] for f in 1:length(instance.set_VNFs),  m in 1:instance.number_of_NFs, u in 1: props(instance.physical_network)[:number_nodes])) 
                             
    
    return my_model

end

function solve_NSDP_model(my_model::Model, policy::String,split_::Int64)

    #exporting CPLEX log
    JuMP.build(my_model)
    intm = internalmodel(my_model).inner
    CPLEX.set_logfile(intm.env, joinpath(result_folder,"LOG_policy_$(policy)_option_$(split_)_of.txt"))
    
    #calling solver
    solve(my_model)
end

function get_solution(my_model::Model, instance::Instance,folder::String,split_::Int64, pol::String)
  
#-------------------- GETTING SOLUTION -----------------------------------      
    sol_z = getvalue(my_model[:z])
    sol_x = getvalue(my_model[:x])
    sol_y = getvalue(my_model[:y])
    sol_w = getvalue(my_model[:w])
    sol_gamma = getvalue(my_model[:gamma])
   
    Objective_value =  getobjectivevalue(my_model)

#-------------------- GETTING NODE LOAD AND NUMBER OF NFS -----------------------------------      
    #auxiliary variables
    charge_node = Array{Float64}(undef, props(instance.physical_network)[:number_nodes])
    total_nodes_capacity = 0.0
    most_loaded = 0.0 
    total_load = 0.0
    number_NFSs = 0.0
    ppn = 0.0
    number_active_node = 0
    dis_NFS = 0
    cent_NFS = 0

    for u in 1: props(instance.physical_network)[:number_nodes]
        charge_node[u] = 0.0
        total_nodes_capacity+=props(instance.physical_network,u)[:cpu_capacity]
        if props(instance.physical_network, u)[:node_type] != "app"
            for f in 1:length(instance.set_VNFs),  m in 1:instance.number_of_NFs
                charge_node[u] += (sol_y[f,m,u]*instance.set_VNFs[f].cpu_request)/props(instance.physical_network,u)[:cpu_capacity]
                total_load += (sol_y[f,m,u]*instance.set_VNFs[f].cpu_request)
                number_NFSs += sol_y[f,m,u]
                if props(instance.physical_network, u)[:node_type] == "non_access"
                    cent_NFS += sol_y[f,m,u]
                else
                    dis_NFS += sol_y[f,m,u]
                end
            end
        end
        if charge_node[u] > 0
            number_active_node += 1
            ppn+=charge_node[u]
            if charge_node[u] > most_loaded
                most_loaded = charge_node[u]
            end
        end
    end
    total_load = total_load/total_nodes_capacity


  #-------------------- GETTING LINK LOAD  -----------------------------------      
    #auxiliary variables
    charge_arc = Array{Float64}(undef, props(instance.physical_network)[:number_of_arcs])
    total_arc_capacity = 0.0
    most_loaded_arc = 0.0 
    total_arc_load = 0.0
    number_active_links = 0
    ppa = 0.0
    ver = 0.0
    
        for a in edges(instance.physical_network) 
        edge_id = get_prop(instance.physical_network,a,:edge_id)
        charge_arc[edge_id] = 0.0
        total_arc_capacity+= get_prop(instance.physical_network,a,:max_bandwidth)

        for s in 1:length(instance.setSlices), k in 1:length(instance.setSlices[s].set_commodities)

            charge_arc[edge_id] += sol_gamma[s,k,edge_id,length(instance.set_VNFs)+1,1]*instance.setSlices[s].set_commodities[k]["volume_of_data"]

            charge_arc[edge_id] += sol_gamma[s,k,edge_id,length(instance.set_VNFs),length(instance.set_VNFs)+1]*instance.setSlices[s].set_commodities[k]["volume_of_data"]*instance.set_VNFs[instance.number_of_AN_based_NFs].compression

            for f in 1:(instance.number_of_AN_based_NFs+instance.number_of_CN_based_NFs), g in 1:(instance.number_of_AN_based_NFs +instance.number_of_AN_based_NFs)
                if f!=g 
                    if f<=instance.number_of_AN_based_NFs&&g<=instance.number_of_AN_based_NFs && sol_gamma[s,k,edge_id,f,g] >0.9
                    charge_arc[edge_id] += sol_gamma[s,k,edge_id,f,g]*instance.setSlices[s].set_commodities[k]["volume_of_data"]*instance.set_VNFs[f].compression
                    end
                    if f>instance.number_of_AN_based_NFs && g>instance.number_of_AN_based_NFs && sol_gamma[s,1,edge_id,f,g]>=0.9
                        charge_arc[edge_id] += sol_gamma[s,1,edge_id,f,g]*instance.set_VNFs[f].amount_of_traffic_sent_to_g[g]*(instance.setSlices[s].TotalAmountUE/length(instance.setSlices[s].set_commodities))
                    elseif f>instance.number_of_AN_based_NFs && g<=instance.number_of_AN_based_NFs && sol_gamma[s,k,edge_id,f,g]>=0.9
                     charge_arc[edge_id] += sol_gamma[s,k,edge_id,f,g]*instance.set_VNFs[f].amount_of_traffic_sent_to_g[g]*(instance.setSlices[s].TotalAmountUE/length(instance.setSlices[s].set_commodities))
                    elseif f<=instance.number_of_AN_based_NFs && g>instance.number_of_AN_based_NFs && sol_gamma[s,k,edge_id,f,g]>=0.9
                        charge_arc[edge_id] += sol_gamma[s,k,edge_id,f,g]*instance.set_VNFs[f].amount_of_traffic_sent_to_g[g]*(instance.setSlices[s].TotalAmountUE/length(instance.setSlices[s].set_commodities))

                    end
                end
            end
        end


        total_arc_load+= charge_arc[edge_id]
         charge_arc[edge_id] =  charge_arc[edge_id]/get_prop(instance.physical_network,a,:max_bandwidth) 
        if charge_arc[edge_id] > 0
            number_active_links += 1
            ppa+=charge_arc[edge_id]
            if charge_arc[edge_id]  > most_loaded_arc
                most_loaded_arc = charge_arc[edge_id] 
            end
        end
    end
    total_arc_load = total_arc_load/total_arc_capacity


#-------------------- PRINTING -----------------------------------      
        
    open(joinpath(result_folder,"load_on_arcs.csv"), "a") do iooo
        open(joinpath(result_folder,"final_statistics.csv"), "a") do io
            open(joinpath(result_folder,"load_on_nodes.csv"), "a") do ioo              

                if split_ == 7
                    write(io,"$(pol)OptionFlex;$(pol);flex;")
                else
                    write(io,"$(pol)Option$(split_);$(pol);$(split_);")
                end


                write(io,"$(Objective_value);")   
                write(io,"$(number_NFSs);")
                write(io,"$(dis_NFS);")
                write(io,"$(cent_NFS);")


                write(io,"$(props(instance.physical_network)[:number_nodes]);")
                write(io,"$(number_active_node);")
                write(io,"$(number_active_node/props(instance.physical_network)[:number_nodes]);")

                write(io,"$(total_nodes_capacity);")
                write(io,"$(total_load);")
                write(io,"$(ppn/number_active_node);")
                write(io,"$(most_loaded);")


                write(io,"$(props(instance.physical_network)[:number_of_arcs]);")
                write(io,"$(number_active_links);")
                write(io,"$(number_active_links/props(instance.physical_network)[:number_of_arcs]);")

                write(io,"$(total_arc_capacity);")
                write(io,"$(total_arc_load);")
                write(io,"$(ppa/number_active_links);")
                write(io,"$(most_loaded_arc)\n")

                for u in 1:props(instance.physical_network)[:number_nodes]
                  node_type = props(instance.physical_network, u)[:node_type] 
                    if split_ == 7
                        write(ioo,"$(u);$(node_type);$(pol);flex;$(charge_node[u])\n")
                    else
                        write(ioo,"$(u);$(node_type);$(pol);$(split_);$(charge_node[u])\n")
                    end
                end


                for a in edges(instance.physical_network) 
                    edge_id = get_prop(instance.physical_network,a,:edge_id)
                    edge_type = ""           
                    if props(instance.physical_network, src(a))[:node_type] == "access" &&  props(instance.physical_network, dst(a))[:node_type]  == "non_access"         
                        edge_type = "fronthaul"
                    elseif props(instance.physical_network, src(a))[:node_type] == "non_access" &&  props(instance.physical_network, dst(a))[:node_type]  == "non_access"         
                        edge_type = "backhaul"
                    elseif props(instance.physical_network, src(a))[:node_type] == "non_access" &&  props(instance.physical_network, dst(a))[:node_type]  == "app"         
                        edge_type = "external"
                    elseif props(instance.physical_network, dst(a))[:node_type] == "non_access" &&  props(instance.physical_network, src(a))[:node_type]  == "app"         
                        edge_type = "external"  
                    elseif props(instance.physical_network, dst(a))[:node_type] == "access" &&  props(instance.physical_network, src(a))[:node_type]  == "non_access"         
                        edge_type = "fronthaul"
                    end               
                    if split_ == 7
                        write(iooo,"$(edge_id);$(edge_type);$(pol);flex;$(charge_arc[edge_id])\n")
                    else
                        write(iooo,"$(edge_id);$(edge_type);$(pol);$(split_);$(charge_arc[edge_id])\n")
                    end
                end
            end 
        end   
    end

    if split_ == 7
        open(joinpath(result_folder,"variables_policy_$(pol)_split_flex_.csv"), "w") do io
            write(io,"z = $(sol_z)\n")
            write(io,"x = $(sol_x)\n")  
            write(io,"y = $(sol_y)\n")   
            write(io,"w = $(sol_w)\n")   
            write(io,"gamma = $(sol_gamma)")                                           
        end
    else
        open(joinpath(result_folder,"variables_policy_$(pol)_split_$(split_)_.dat"), "w") do io
            write(io,"z = $(sol_z)\n")
            write(io,"x = $(sol_x)\n")  
            write(io,"y = $(sol_y)\n")   
            write(io,"w = $(sol_w)\n")   
            write(io,"gamma = $(sol_gamma)")  
        end
    end
                                                    
        
end


