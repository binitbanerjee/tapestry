				Poject 3: Implementation of 'Tapestry'
			Team: Binit Banerjee 7893 0346 , Shreya Chakraborty 3441 9171

What is working:
1. We have implemented the tapestry.
2. Each peer send a fixed number or "requests" as entered in the parameter while executing the code.
3. The code continues till all messages reach the destination root node.
4. Each peer is assigned a key using the SHA1 hashing. The address space here used is of 80 bits string and not 160 bits string.
4. The maximum hop among all such recieved nodes are printed as an output.
5. Intially 95% of the peers are started, with 5 % being added dynamically later.


Steps to run:
1. Unzip the folder and open project3.
2. In terminal navigate to the folder which contains the "project3.exs". It should be inside the project3 folder.
3. Run the command : mix run project3.exs 1000 10 
4. in the above 1000 is the number of nodes and 10 is the number of requests.

The largest network that worked is :
4000 nodes with 10 requests per node.
				      


