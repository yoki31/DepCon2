# DepCon2 관련 내용 및 실험 방법 정리
## DepCon2 연구
* DepCon2 연구는 기존 DepCon의 한계를 개선하려는 연구
* 기존 DepCon 연구는 Kubernetes 환경에서 DepCon scheduler를 이용하여 network 목표 성능을 달성하기에 적합한 환경을 선택(이 과정에서 network bandwidth에 대한 filtering을 제공하고 network 목표 성능 달성을 위해 정확히 얼만큼의 CPU가 필요한지 알 지 못하므로 할당 가능한 CPU가 많은 서버에 컨테이너를 생성하였다.)하고 DepCon agent를 이용하여 각 컨테이너의 CPU 할당량을 동적으로 조절하여 network SLO를 달성한다. 
* DepCon2 연구는 network 목표 성능 달성을 위해 필요한 CPU를 트레이닝 데이터를 이용하여 예측하고, 예측한 CPU와 network를 기반으로 Kubernetes에서 스케줄링을 제공한다. 각 서버에서 CPU 할당량을 제어할 필요 없이 network 성능 달성을 위한 정해진 양의 CPU를 할당하여 네트워크 성능을 달성할 수 있도록 한다. 

## DepCon2 스케줄링 데이터 수집 방법
* CPU quota(사용가능한 CPU)를 제한 하였을 때의 network bandwidth를 측정

### DepCon2 데이터 수집 환경
* Intel E5-2650 v3 10 cores CPU, 128GB memory, 10GbE network interface
* Kubernetes v1.21.1, Docker v20.10

### DepCon2 데이터 수집 방법
* 10Gb Ethernet으로 연결된 2대의 서버에서 Kubernetes 환경을 셋팅하여 실험 진행
	* oslab(1번 서버 - netserver, master) oslab2(2번 서버 - netperf, worker) 를 이용
* pod 1개를 띄워 CPU quota 값을 2500, 5000, 10000 단위로 설정하여 데이터를 수집
	* 예) 1개의 pod에 대해서 cpu quota별(2500, 7500, 12500, … 102500 : 5000 단위)로 패킷 사이즈를 (32, 64,128, 256, 512, 1024)로 변경

### DepCon2 데이터 수집을 위한 세팅 방법
* 디렉토리 - /home/oslab2/eskim/depcon_expansion/data_script
* Kubernetes 클러스터 구성 (1번 서버 - master, 2번 서버 - worker)
	* [우분투 Kubernetes 설치 방법 - HiSEON](https://hiseon.me/linux/ubuntu/ubuntu-kubernetes-install/)
* 1번 서버(oslab)에서 netserver 실행
	* netserver -p 1
* pod 생성 
	* kubectl create -f p1.yaml
```
kind: Pod
apiVersion: v1
metadata:
  name: p1
spec:
  containers:
    - name: p1
      image: dkdla58/ubuntu:netperf
      command: ["/bin/bash", "-ec", "while :; do echo '.'; sleep 5 ; done"]
      resources:
        limits:
          cpu: 100m #2500, 7500, 12500, 17500, ... 100000
  restartPolicy: Never
```
* p1.yaml 파일에서 image는 netperf, vnstat 등 데이터 수집에 필요한 툴이 설치되어 있는 이미지 파일
* resources: limits: cpu: -> cpu의 limit을 정할 수 있는 항목이고, cpu의 limit만 설정하면 자동으로 cpu request도 설정된다. Cpu의 limit 값으로 cpu quota 값이 결정된다. 
* cpu: 100m -> quota  값 : 100000 과 같음
	* 2500 == 25m, 7500 == 75m, 12500 == 125m
* kubectl get pods를 이용하여 STATUS가 Running 상태인지 확인하고 Running 상태가 되면 아래의 스크립트를 사용하여 실험 진행 

* 실험 스크립트
	* ./netperf_pod.sh p32[디렉토리 명]
```
#!/bin/bash

pkt=32

mkdir $1

for i in $(seq 1 6)
do
        echo $pkt
        mkdir $1/p${pkt}

        for j in $(seq 1 10)
        do
                mkdir $1/p${pkt}/$j
                kubectl exec -it p1 --namespace=default -- netperf -H 10.0.0.25 -p 1 -l 123 -- -m ${pkt}&
                sleep 1
                kubectl exec -it p1 --namespace=default -- vnstat -tr 120 > $1/p${pkt}/$j/vnstat.txt&
                pidstat -G netperf 120 1 > $1/p${pkt}/$j/pidstat.txt & mpstat -P ALL 120 1 > $1/p${pkt}/$j/mpstat.txt
                sleep 3
        done
        ((pkt=${pkt}*2))
done
```
* 설정한 quota 크기별로 packet 사이즈를 32, 64, 128, 256, 512, 1024 늘리며 실험 진행, 각 패킷 사이즈별로 10번씩 실험 진행
	* pod 내부에서 netperf, vnstat을 실행하여 실험 진행 
* 실험이 끝나고 kubectl delete -f p1.yaml을 입력하여 pod 삭제 후 p1.yaml에서 cpu limit을 그 다음 실험 quota로 변경하여 실험 
	* 삭제 및 생성 반복하여 실험 진행

* ./main.sh
	* quota 사이즈 별로 pod 생성 삭제가 귀찮고, netperf 실험을 quota 사이즈별로 자동으로 하고 싶으면 해당 스크립트 실행하면 됨
		* quota 사이즈를 바꿀 때마다 pod를 삭제하고 생성하고를 반복해야 하므로 pod가 Running 상태가 되면, netperf 스크립트를 실행하도록 스크립트 작성
			* 약간의 수정이 필요할 수 있음
```
#!/bin/bash

quota=100

mkdir q10
kubectl create -f p1.yaml

a=''
while [ "$a" != "Running" ]
do
a=`kubectl get pods | awk '{print $3}' |tail -1`;
sleep 1
done

sh netperf_pod.sh q10
sleep 2
kubectl delete -f p1.yaml
sed -i "s/10m/100m/g" p1.yaml

for i in $(seq 1 10)
do
        mkdir q${quota}
        kubectl create -f p1.yaml

        a=''
        while [ "$a" != "Running" ]
        do
        a=`kubectl get pods | awk '{print $3}' |tail -1`;
        sleep 1
        done

        sh netperf_pod.sh q${quota}
        sleep 2
        kubectl delete -f p1.yaml
        ((tmp=${quota}+100))
        sed -i "s/${quota}m/${tmp}m/g" p1.yaml
        quota=$tmp
done
```
* ./sum.sh 
	* 각 quota 사이즈별 디렉토리에 sum.sh 를 copy하여 vnstat, pidstat, mpstat 별 텍스트 파일을 추출할 수 있음 
	* 10번 실험 기준!

### 실험 데이터 디렉토리
* /home/oslab2/eskim/depcon_expansion/data_script
* /home/oslab2/eskim/depcon_expansion/data_script/raw_data_2500
	* cpu quota 2500 간격으로 2500, 10000 ~ 102500
* /home/oslab2/eskim/depcon_expansion/data_script/raw_data_5000
	* cpu quota 5000 간격으로 5000, 15000 ~ 105000
* /home/oslab2/eskim/depcon_expansion/data_script/raw_data_10000
	* cpu quota 10000 간격으로 1000, 10000 ~ 100000

* [참고] 또 다른 스크립트들 정리 
	* 아래의 스크립트 들은 pod를 여러 개 생성할 때 사용하는 스크립트이고, 데이터 수집에는 한 개의 pod 만 띄우므로 사용하지 않음 
		* edit_pnum.sh : 여러 pod를 생성할 때 pod의 name을 바꾸기 위한 스크립트 
		* edit.sh : 여러 pod를 생성할 때 network bandwidth나 CPU quota를 변경하기 위한 스크립트 


## DepCon2에서 network bandwidth 및 CPU를 고려하여 스케줄링 하는 방법
* Kubernetes의 스케줄링 과정에서 DRF를 적용하여 CPU와 network를 fair하게 할당해줄 수 있는 Container를 선택하는 방향으로 구현을 하려 하였으나 컨테이너 환경에서는 자원을 나눠서 컨테이너에 할당하도록 스케줄링 하면 pending 상태로 지속되는 시간이 발생하기 때문에 비효율적임
	* 그래서, DRF를 적용하여 컨테이너의 생성 순서를 조정하는 kube-batch라는 오픈소스가 있는 데 이는 batch job에서 효율적이고 일반적인 클러스터 환경에는 적합하지 않음
* 그래서, Kubernetes의 balancedResource  플러그인을 수정하여 새로운 DepCon2 스케줄러를 구현 
	* 여기에서 balancedResource 플러그인은 기존 Kubernetes에 있던 플러그인으로 컨테이너를 생성할 때 서버들의 CPU와 memory가 비율적으로 균등하게 유지되도록 컨테이너를 생성함. -> 하나의 서버에 컨테이너가 몰려서 하나의 자원이 부족한 경우가 최대한 발생하지 않도록 하기 위함
	* DepCon2 scheduler에서 CPU, memory, network가 균등한 서버를 찾아서 컨테이너 생성
* (1) network에 대한 Filtering과정 (2) network, cpu, memory 자원의 비율에 대해 고려한 Scoring 과정

- - - -
### DepCon2 스케줄러 filtering 구현 방법
* 먼저, DepCon2 스케줄러에서 network SLO만큼의 network bandwidth를 제공할 수 없는 서버는 pod를 생성할 서버에서 제외한다. 
* Kubernetes에서 기본적으로 제공하는 자원인 CPU, memory 외의 다른 자원에 대해 filtering을 제공하고 싶으면 API server에 추가할 자원 항목과 그에 대한 capacity를 추가해야 한다. 
	* 새로운 노드-레벨의 확장된 리소스를 알리기 위해, 클러스터 운영자는 API 서버에 PATCH HTTP 요청을 제출하여 클러스터의 노드에 대해 status.capacity에서 사용할 수 있는 수량을 지정할 수 있음.
* ./slo_setting.sh [network interface name]
	* 위의 커맨드를 실행하여 모든 노드에 network SLO 자원 항목을 추가할 수 있음 
	* network SLO라는 항목을 사용할 모든 노드에 자원을 추가해야됨 -> 스크립트에서 해줌
```
#!/bin/bash
speed=`ethtool $1 | grep Speed`
speedBack="${speed#*Speed: }"
value="${speedBack%%Mb/s*}"

nodes=$(echo "`kubectl get nodes`" | awk '{print $1}' | sed -n "2, \$p")
pid=`ps -ef | grep "kubectl proxy" | grep -v 'grep' | awk '{print $2}'`
if [ -z $pid ];then
  kubectl proxy &
fi

for node in $nodes
do
        curl --header "Content-Type: application/json-patch+json" \
        --request PATCH \
        --data '[{"op": "add", "path": "/status/capacity/example.com~1SLO", "value": '`expr $value \* 1000000`'}]' \
        http://localhost:8001/api/v1/nodes/$node/status
done
```
* ethtool로 Ethernet의 network bandwidth를 얻어옴
* 모든 노드들의 리스트를 얻어오고 kubectl proxy를 이용하여 kubernetes proxy를 실행 -> proxy 실행으로 API server에 연결 가능
* ethtool에서 network bandwidth가 Mbps 단위로 출력이 되기 때문에 전체 capacity는 Mbps 만큼 곱하여 API server에 등록함.

- - - -
### DepCon2 스케줄러 scoring 구현 방법
* BalancedResource 플러그인 디렉토리
	* /home/oslab/eskim/depcon2_k8s/pkg/scheduler/framework/plugins/noderesources/balanced_allocation.go
* Kubernetes는 기본스케줄러와 함께 제공되고 기본 스케줄러가 필요에 맞지 않는 경우 자체 스케줄러를 구현할 수 있다. 또한, 기본 스케줄러와 함께 여러 스케줄러를 동시에 실행하고 kubernetes에게 각 포드에 사용할 스케줄러를 지시할 수도 있다. 

#### Kubernetes BalancedResource 플러그인 소스코드 수정
* balanced_allocation.go에서 balancedResourceScorer 함수 수정
	* networkFraction 추가
`networkFraction := fractionOfCapacity(requested["example.com/SLO"], allocable["example.com/SLO"])`
		* network 비율 = 요청한 Network SLO / 각 서버에서 할당 가능한 network bandwidth
	* networkFraction이 1보다 크면 요청한 network SLO보다 할당 가능한 network bandwidth가 작으면 값을 1로 할당
```
if networkFraction > 1 {
        networkFraction = 1
}
```
* cpu request는 전체 capacity를 넘을 수 있으므로 이러한 경우가 발생 가능함

* cpu, memory, volume, network에 대한 fraction의 편차를 계산 -> volume이 비율 계산에 포함이 되는 경우
```
mean := (cpuFraction + memoryFraction + volumeFraction + networkFraction) / float64(4)
variance := float64((((cpuFraction - mean) * (cpuFraction - mean)) + ((memoryFraction - mean) * (memoryFraction - mean)) + ((volumeFraction - mean) * (volumeFraction - mean)) + ((networkFraction - mean) * (networkFraction - mean))) / float64(4))
```
	* cpu, memory, volume, network에 대한 fraction의 편차를 계산 -> volume이 비율 계산에 포함이 되지 않는 경우
```
mean := (cpuFraction + memoryFraction + networkFraction) / float64(3)
variance := float64((((cpuFraction - mean) * (cpuFraction - mean)) + ((memoryFraction - mean) * (memoryFraction - mean)) + ((networkFraction - mean) * (networkFraction - mean))) / float64(3))
```
* 값을 반환할 때 scoring boundary인 1~10에 포함되도록 설정하여 반환
`return int64((1 - variance) * float64(framework.MaxNodeScore))`

* resource_allocation.go에서 defaultRequestedRatioResources 추가
	* resourceToWeightMap에 “example.com/SLO” 를 기본 값인 1로 설정
`var defaultRequestedRatioResources = resourceToWeightMap{v1.ResourceMemory: 1, v1.ResourceCPU: 1, "example.com/SLO": 1}`

#### 스케줄러 패키징
* [디렉토리] : /home/oslab/eskim/eskim_git/depcon2_k8s
* 스케줄러 바이너리를 컨테이너 이미지로 패키징한다. 이 예에서는 기본 스케줄러를 두번째 스케줄러로 사용할 수 있다. 
-> github의 스케줄러 소스코드를 받아오고 빌드하면 됨. 
```
git clone https://github.com/kubernetes/kubernetes.git
cd kubernetes
make
```
* kube-scheduler 바이너리를 포함하는 컨테이너 이미지를 만든다. Dockerfile 이미지를 빌드하는 방법은 다음과 같다. 
```
FROM busybox
ADD ./_output/local/bin/linux/amd64/kube-scheduler /usr/local/bin/kube-scheduler
```
* 파일로 저장하고 Dockerfile 이미지를 빌드
`docker build -t depcon2-scheduler:v1 .`
	* [참고]  본인의 docker hub에 push 하여 사용하는게 좋을듯 

#### 스케줄러에 대한 kubernetes 배포 정의
* 이제 컨테이너 이미지에 스케줄러가 있으므로 이에 대한 포드 구성을 만들고 Kubernetes 클러스터에서 실행한다. 그러나, 클러스터에서 직접 pod를 생성하는 대신 이 예제에 deployment를 사용할 수 있다. 
```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: depcon2-scheduler
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: depcon2-scheduler-as-kube-scheduler
subjects:
- kind: ServiceAccount
  name: depcon2-scheduler
  namespace: kube-system
roleRef:
  kind: ClusterRole
  name: system:kube-scheduler
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: depcon2-scheduler-as-volume-scheduler
subjects:
- kind: ServiceAccount
  name: depcon2-scheduler
  namespace: kube-system
roleRef:
  kind: ClusterRole
  name: system:volume-scheduler
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    component: scheduler
    tier: control-plane
  name: depcon2-scheduler
  namespace: kube-system
spec:
  selector:
    matchLabels:
      component: scheduler
      tier: control-plane
  replicas: 1
  template:
    metadata:
      labels:
        component: scheduler
        tier: control-plane
        version: second
    spec:
      serviceAccountName: depcon2-scheduler
      containers:
      - command:
        - /usr/local/bin/kube-scheduler
        - --address=0.0.0.0
        - --leader-elect=false
        - --scheduler-name=depcon2-scheduler
        image: depcon2-scheduler:v1
        livenessProbe:
          httpGet:
            path: /healthz
            port: 10251
          initialDelaySeconds: 15
        name: depcon2-scheduler
        readinessProbe:
          httpGet:
            path: /healthz
            port: 10251
        resources:
          requests:
            cpu: '0.1'
        securityContext:
          privileged: false
        volumeMounts: []
      hostNetwork: false
      hostPID: false
      volumes: []
```

* 여기에서 주목해야 할 중요한 점은 컨테이너 사양에서 스케줄러 명령에 대한 인수로 지정된 스케줄러의 이름이 고유해야 한다는 것이다. 
-> —scheduler-name= [스케줄러 이름]
이 spec.schedulerName 스케줄러가 특정 Pod의 스케줄링을 담당하는지 여부를 판단하기 위해 pod의 선택적 값과 일치하는 이름이다. 
또한, 전용 서비스 계정을 depcon2-scheduler 로 만들고 cluster role system:kube-scheduler 를 kube-scheduler 와 같은 권한을 가지도록 설정한다. 

* serviceaccount를 설정하여 kube-system에 등록된 depcon2-scheduler를 사용할 수 있도록 설정
```
cd eskim
kubectl create -f serviceaccount.yaml
```

#### pod에 대한 스케줄러 지정
* 이제 두 번째 스케줄러가 실행 중이므로 일부 pod를 만들고 기본 스케줄러 또는 배포한 스케줄러에 의해 스케줄링 되도록 지시한다. 특정 스케줄러를 사용하여 지정된 포드를 예약하려면 해당 포드 사양에서 스케줄러의 이름을 지정한다. 
* 3가지 예가 있다. 
	* 스케줄러 이름이 없는 pod는 default-scheduler를 사용하여 자동으로 스케줄링된다. 
	* default-scheduler로 지정을 하면 default-scheduler로 설정됨
	* depcon2-scheduler로 지정한 경우 사용자 지정 스케줄러로 스케줄링 됨. 
	* p1.yaml
```
kind: Pod
apiVersion: v1
metadata:
  name: p1
spec:
  schedulerName: depcon2-scheduler
  containers:
    - name: p1
      image: dkdla58/ubuntu:netperf
      resources:
        limits:
          example.com/SLO: 300
        requests:
          cpu: "100m"
      command: ["/bin/bash", "-ec", "while :; do echo '.'; sleep 5 ; done"]
  restartPolicy: Never
```

#### 새로 생성한 스케줄러로 pod가 스케줄링 되었는지를 확인하는 방법
* pod 및 deployment 구성 제출 순서를 변경하여 확인할 수 있는데 스케줄러 배포 구성을 제출하기 전에 모든 포드 구성을 kubernetes 클러스터에 제출 하면 다른 두 포드가 스케줄링되는 동안 나머지 하나의 포드가 pending 상태로 남게 된다. 
* 혹은 이벤트 로그에서 “Scheduled” 항목을 보고 원하는 스케줄러에 의해 pod가 스케줄링되었는지를 확인할 수 있다.
`kubectl get events`

### DepCon2 스케줄러 동작 테스트
* 테스트 방법 
	* (1) Intel E5-2650 v3 10 cores CPU, 256GB memory를 가지는 서버들 (1,3,4,6,8,10 번 서버)에서 pod가 하나의 서버에 몰리는 현상이 발생하지 않는지를 판단
	* (2) 총 10대의 서버에서 100개의 컨테이너를 생성하고, DepCon agent를 이용했을 때 목표 성능을 모두 달성할 수 있는지 확인
	* (3) pod를 4개의 그룹으로 나눴을 때 2개의 그룹은 64bytes, 2개의 그룹은 1024bytes로 실험하여 네트워크 성능을 모두 달성할 수 있는 지 확인
		* 메시지 크기가 64bytes일 때, 네트워크 목표 성능이 높은 pod가 더 많은 처리를 해야되므로 CPU 사용량이 높아지게 됨. 
			* CPU 사용량 높고 network 사용량 적음
		* 메시지 크기가 1024bytes일 때, 네트워크 목표 성능이 높은 pod의 CPU 사용량은 높지 않지만, 네트워크 사용량이 높음
			* CPU 사용량 적고, network 사용량 많음
* (1) 방법을 이용하여 pod들이 하나의 서버에 몰리지 않는 것을 확인
	* sh cp_pod.sh 
		* 100개의 pod yaml 파일을 생성하기 위해 사용
	* sh edit_pnum.sh 
		* 한개의 pod를 복사하여 100개의 pod yaml을 만들었기 때문에 이 스크립트를 이용하여 pod 이름을 바꿔줌
	* sh edit.sh
		* SLO 값이 랜덤으로 배정된 b.txt를 이용하여 pod를 p1부터 p100까지 SLO에 할당된 값을 변경해줌
			* SLO는 100Mbps면 100000000으로 설정 필요
		* CPU를 예측하여 값을 넣게 된다면, SLO 값을 랜덤으로 넣고 그 SLO 값에 맞는 예측 CPU를 할당하여 pod를 생성
	* sh create_pod.sh 
		* SLO 값이 랜덤으로 설정된 pod들을 생성하는 스크립트 
* 나머지 방법들은 인수인계 받아서 진행하는 측에서 실험 진행 
