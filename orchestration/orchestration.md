Orchestration
===

Course grained orchestration
---

Course grained orchestration can be achieved by dividing the overall task into multiple
catalogs and waiting for these catalogs to be completed. Such an orchestration can be
achieved with the current Puppet agent technology.

An orchestration service would know about the individual "part" catalogs, and would make decisions
on the outcome of their application by looking at the result in Puppet DB.

This requires that agents are kicked into getting their next part when the orchestration
service decides the next part-catalog should be applied. The application of the
catalog is one uninterrupted flow.

This can be made to work fine if there are only a few orchestration points; i.e. each
host reaches its desired end state after 1-3 runs. The overall throughput is however
expected to be slow since each orchestration point requires full roundtrips and
application of complete catalogs.

This can also be improved by creating a catalog consisting of sections (i.e. multiple
catalogs sent as one catalog to the agent), and where the agent applies the catalogs
in sequence (after possibly waiting for values in-between).

Fine grained orchestration
---
Fine grained orchestration can be achieved by making the agent have an active communication
channel with the orchestration service. The agent receives a catalog that contains
Futures - something that resolves to a value when the value is available. Thus, the agent
can perform all work that can be done before a particular Future is required. The active communication
with the orchestration service may have received notification of the future value being
available while the agent was performing its work, and in the best of cases, no waiting is
required.

The reverse takes place when an agent is responsible for producing a Future value (that
others are waiting for).


A Minimalistic Implementation
---

A minimalistic implementation of fine grained orchestration can be achieved in different ways.
Essentially, all that is needed is to be able to reliably read/write future values (more
is however needed to achieve actual orchestration, avoid dead-locks etc). While the core
mechanism is simple this takes place in a distributed environment, it needs a competent
service that can reach a quorum.

The etcd service is such a service implemented on top of the Raft protocol. While etcd is a great service:

* I am not sure it runs everywhere
* all participating nodes gets to see all the data
* does not scale (since data is propagated to all nodes)
* uses blocking long HTTP poll for notifications

Hence, just like with all other distributed solutions, agents needs to be clients of a service
with similar traits to etcd, they cannot all be participants in the etcd cluster. The etcd
does not yet have any security / ACL or mechanisms for clients of a cluster.

However, using etcd is very simple and may be ideal for a small POC.

A Real Implementation
---
A real implementation would use a client to cluster communication protocol that is bi-directional
and light-weight. Web-sockets seems like a very good candidate. Thus each agent has one web-socket
connection to the orchestration service. (This communication is secured using wws: (secure web socket)).

The orchestration service runs in a cluster that uses some cluster technology
(etcd, hazelcast, etc.). It is fronted by a load balancer that directs the traffic to
one machine in the cluster. The agent web-socket will have affinity to one machine in the cluster
and if this machine goes down, or the agent receives a message to reconnect (cluster is
reconfigured and load should be spread on additional nodes), it will need to establish a new connection. The web-socket connection could also be cycled with a reconnect on a schedule to
ensure that cluster reconfiguration / re-balancing takes place.

It is clearly possible to send simple messages that achieves orchestration; apply new catalog,
run same catalog again, restart, etc. The protocol could also include messages to make the
agent update itself etc. It becomes a lot more interesting when the agent can apply a catalog an
get values 'just in time' and block until such values become available.

Technically, it is still just reading keys (and making requests that waits for a key to become
available). We probably also want data to have a TTL (Time to Live) to ensure that the agent does
not act on stale data.

We could use etcd as a local mechanism as it provides persistence, and allows applications to conveniently pick up values. In fact, this allows the communication part of the agent to run as
a service / relay to etcd and to run puppet as a separate process using etcd (or some other mechanism) to perform read and write.

Petri nets
---
Tools ePNK (Petri Net Kernel)
Editor, simulator, based on EMF Ecore and PNML
http://www2.imm.dtu.dk/~ekki/projects/ePNK/PDF/ePNK-manual-1.0.0.pdf
