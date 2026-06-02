/* Communication manager
     If the tcp server port of the client is to be run in private network and made visible via ngrok (tunneled = yes), no stun testing is done, and the server is started on given private IP and port. In case the server socket cannot be started, failure message is returned as string.
     It is also possible to invoke the server port setup without argument for the same case (server made visible via ngrok tunneling). In this case, server is started on any available IP and port. The same is indicated back in returned string. On failure, failure message is returned as string.
     Now test using stun server is invoked to check if the node is behind NAT or not.
     If the node is not behind NAT,
        then server is started on existing public IP and port.
        message handler function is attached to the created socket.
        the public IP and port are also returned as string. Calling code will use put this as endpoint address Routing Table for local node.
     If the node is behind NAT,
        then invoke proxySetup with NodeID, proxy IP, proxyPort as argument. 
        The function  setups the tcp connection (socket) to proxy IP and port. It forms a message as follows
            [register, nodeID].
        On success, the returned message contains pubIP and pubPort created on proxy node for this nodeID. This is returned back to calling function. On receipt of failure message, the same is returned back to calling function.
     
     
*/
 /*startNoCheck()*/
    /* Starts the server port without checking
    */
