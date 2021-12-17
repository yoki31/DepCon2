
package main

//import (
//	"flag"

//	"k8s.io/klog"
	//"github.com/golang/glog"
//)

//func main() {
//	klogFlags := flag.NewFlagSet("klog", flag.ExitOnError)
//        klog.InitFlags(klogFlags)
//	klog.Info("start")
//	flag.CommandLine.VisitAll(func(f1 *flag.Flag) {
//                f2 := klogFlags.Lookup(f1.Name)
//                if f2 != nil {
//                        value := f1.Value.String()
//                        f2.Value.Set(value)
//                }
//        })
//
//	klog.V(3).Infof("Enter Backfill ...")	
//	klog.Flush()
//}

import (
        "flag"

        "github.com/golang/glog"
        "k8s.io/klog"
)

func main() {
        flag.Set("alsologtostderr", "true")
        flag.Parse()

        klogFlags := flag.NewFlagSet("klog", flag.ExitOnError)
        klog.InitFlags(klogFlags)

        // Sync the glog and klog flags.
        flag.CommandLine.VisitAll(func(f1 *flag.Flag) {
                f2 := klogFlags.Lookup(f1.Name)
                if f2 != nil {
                        value := f1.Value.String()
                        f2.Value.Set(value)
                }
        })

        glog.Info("hello from glog!")
        klog.Info("nice to meet you, I'm klog")
        glog.Flush()
        klog.Flush()
}

