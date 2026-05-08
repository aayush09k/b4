/* Communication manager
     If the tcp server port of the client is to be run in private network and made visible via ngrok (tunneled = yes), no stun testing is done, and the server is started on given private IP and port. In case the server socket cannot be started, failure message is returned as string.
     It is also possible to invoke the server port setup without argument. In this case, server is started on any available IP and port. The same is indicated back in returned string. On failure, failure message is returned.
     Otherwise, server port setup can be invoked with tunneled = no. In this case, IP address and port of proxy node, and own node ID is passed as argument. The function  setups the tcp connection to proxy IP and port. It forms a message as follows
     [register, nodeID].
     
     
*/
/ startNoCheck()
    /** Starts the server port without checking
    */
