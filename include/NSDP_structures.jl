
################################################################################
#
# Thesis title: Modeling and Optimization for 5G Network Design
# Ph.D. student: Wesley DA SILVA COELHO
# Thesis Director : Stefano SECCI (Conservatoire National des Arts et Métiers - CEDRIC)
# Thesis Supervisors : Amal BENHAMICHE and Nancy PERROT (Orange Labs)
#
################################################################################

using LightGraphs #Package to construct simple graphs to plot
using MetaGraphs#Package to construct complex graphs to plot

struct VNF
           id::Int8
           typee::Symbol
           treatment_capacity::Float16
           dataVolPerUE::Float16
           cpu_request::Float16
           ram_request::Float16
           storage_request::Float16
           compression::Float16 
           amount_of_traffic_sent_to_g::Vector{Float16}
           UE_dependency::Int64 
    
    
           VNF(id::Int64,typee::Symbol,treatment_capacity::Float64,dataVolPerUE::Float64,cpu_request::Float64,ram_request::Float64,storage_request::Float64, compression::Float16, amount_of_traffic_sent_to_g::Vector{Float16},UE_dependency::Int64) = new(id,typee,treatment_capacity,dataVolPerUE,cpu_request,ram_request,storage_request,compression,amount_of_traffic_sent_to_g,UE_dependency)

end

struct SliceRequest
        id::Int8 
        TotalAmountUE::Int16
        minBandwidth::Float16
        setVNFtoInstall::String
        VNFs_To_Connect::String
        VNF_sharing_file::String
        VNF_sharing::Dict
        set_VNFs_to_install::Vector{Int16}
        set_commodities::Vector{Dict}
        maxLatencyDataLayer::Float16
        nodeSharing::Vector{Int8}
        
        
        SliceRequest(id::Int8,TotalAmountUE::Int16,minBandwidth::Float16,setVNFtoInstall::String, VNFs_To_Connect::String, VNF_sharing_file::String,VNF_sharing::Dict,set_VNFs_to_install::Vector{Int16},set_commodities::Vector{Dict},maxLatencyDataLayer::Float16,nodeSharing::Vector{Int8}) = 
                 new(id,TotalAmountUE,minBandwidth,setVNFtoInstall,VNFs_To_Connect, VNF_sharing_file,VNF_sharing,set_VNFs_to_install,set_commodities,maxLatencyDataLayer,nodeSharing)
end

mutable struct Instance
        set_VNFs::Vector{VNF}
        physical_network::MetaDiGraph
        setSlices::Vector{SliceRequest}
        VNF_connection::Dict
        number_of_NFs::Int16
        number_of_AN_based_NFs::Int16
        number_of_CN_based_NFs::Int16
        maxLatencyBetweenFunctions::Array{Any,1}
        slice_cont::Array{Any,1}
        band_link_total::Float16
        maxLatencyBetweenDU_NFS1::Float16
        Instance(set_VNFs::Vector{VNF}, physical_network::MetaDiGraph, setSlices::Vector{SliceRequest}) =  new(set_VNFs,physical_network,setSlices)
end

        


