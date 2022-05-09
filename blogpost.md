# Kubernetes backup, restore and migration with Velero - on Azure

**Note:** This is an abstract of an engineering blog. The scenario covered in this document, and the steps performed are done on Microsoft cloud (Azure).

## Introduction:

Until sometime ago, Kubernetes backup and restore used to be very challenging and involved process. However, with [Velero](https://velero.io) it is now almost a piece of cake!

Consider a situation where you have a Kubernetes cluster, which you would like to upgrade/migrate to a newer cluster with newer configuration. In that case, you would like to save the complete state of each namespace, especially the precious persistent data stored in the various persistent volumes, and take it to the new cluster. Velero can help you with that. It (Velero) does this by using bucket/BLOB storage in the cloud. It takes snapshots of your PV and PVCs, and stores them in the bucket store. It also takes snapshots of various other objects, such as deployments, statefulsets, daemonsets, configmaps, secrets, etc. Once a newer cluster is setup and Velero is configured to talk to the new kubenretes cluster, you can restore all of these objects in the new cluster, thus making this upgradation/migration process a breeze. Normally the backup is performed at a namespace level. i.e. You simply take full backup of a namespace and restore the entire namespace in the new cluster.

A couple of months ago, we had a similar situation. We had a Kubernetes cluster in AKS (Azure Kubernetes Service) - which we wanted to reconfigure, but that re-configuration was only possible in a new cluster. We also had some persistent data in this cluster, which needed to move to the newer cluster. This meant that we needed a backup and restore mechanism; and we found **Velero** to be suitable for this task. 

Below is a conceptual diagram of what is described above.


| ![images/velero-backup.png](images/velero-backup.png) |
|-------------------------------------------------------|


**Note:** It is assumed that the old and new k8s clusters are part of the same Azure subscription.

Although it is very much possible to setup **Velero** on your local/home/work computer, and get all of this done. We decided to create a dedicated VM (CENTOS 7.9) in MS cloud to handle backup and restore from several clusters. This helped us keeping the operational control at a central place instead of spreading it on every team member's computer. 


To read the full article and be able to access the related support files, click [this link](https://github.com/C4IROcean/velero-backup-for-kubernetes/blob/master/README.md) .

