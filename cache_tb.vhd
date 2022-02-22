library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cache_tb is
end cache_tb;

architecture behavior of cache_tb is

component cache is
generic(
    ram_size : INTEGER := 32768
);
port(
    clock : in std_logic;
    reset : in std_logic;

    -- Avalon interface --
    s_addr : in std_logic_vector (31 downto 0);
    s_read : in std_logic;
    s_readdata : out std_logic_vector (31 downto 0);
    s_write : in std_logic;
    s_writedata : in std_logic_vector (31 downto 0);
    s_waitrequest : out std_logic; 

    m_addr : out integer range 0 to ram_size-1;
    m_read : out std_logic;
    m_readdata : in std_logic_vector (7 downto 0);
    m_write : out std_logic;
    m_writedata : out std_logic_vector (7 downto 0);
    m_waitrequest : in std_logic
);
end component;

component memory is 
GENERIC(
    ram_size : INTEGER := 32768;
    mem_delay : time := 10 ns;
    clock_period : time := 1 ns
);
PORT (
    clock: IN STD_LOGIC;
    writedata: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
    address: IN INTEGER RANGE 0 TO ram_size-1;
    memwrite: IN STD_LOGIC;
    memread: IN STD_LOGIC;
    readdata: OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
    waitrequest: OUT STD_LOGIC
);
end component;
	
-- test signals 
signal reset : std_logic := '0';
signal clk : std_logic := '0';
constant clk_period : time := 1 ns;

signal s_addr : std_logic_vector (31 downto 0);
signal s_read : std_logic;
signal s_readdata : std_logic_vector (31 downto 0);
signal s_write : std_logic;
signal s_writedata : std_logic_vector (31 downto 0);
signal s_waitrequest : std_logic;

signal m_addr : integer range 0 to 2147483647;
signal m_read : std_logic;
signal m_readdata : std_logic_vector (7 downto 0);
signal m_write : std_logic;
signal m_writedata : std_logic_vector (7 downto 0);
signal m_waitrequest : std_logic; 

begin

-- Connect the components which we instantiated above to their
-- respective signals.
dut: cache 
port map(
    clock => clk,
    reset => reset,

    s_addr => s_addr,
    s_read => s_read,
    s_readdata => s_readdata,
    s_write => s_write,
    s_writedata => s_writedata,
    s_waitrequest => s_waitrequest,

    m_addr => m_addr,
    m_read => m_read,
    m_readdata => m_readdata,
    m_write => m_write,
    m_writedata => m_writedata,
    m_waitrequest => m_waitrequest
);

MEM : memory
port map (
    clock => clk,
    writedata => m_writedata,
    address => m_addr,
    memwrite => m_write,
    memread => m_read,
    readdata => m_readdata,
    waitrequest => m_waitrequest
);
				

clk_process : process
begin
  clk <= '0';
  wait for clk_period/2;
  clk <= '1';
  wait for clk_period/2;
end process;

test_process : process
begin

-- put your tests here

wait for clk_period;

        
-- w & !v & !t & d
-- w & !v & t & d
-- r & !v & !t & d
-- r & !v & t & d
-- cases not possible. Invalid data cannot be dirty.

-- compulsary miss  w & !v & !t & !d
-- write 14 to address 12. No offset. set index 00010. tag 000000.
-- will miss and replace word at set index
-- compare tags again, hit and perform the write. 
-- Dirty bit should be set.

        s_addr <= B"00000000000000000000000000001000"; 
        s_writedata <= X"14";
        s_write <= '1';
		  s_read <= '0';
		  
		  wait for clk_period;
        
        wait until rising_edge(s_waitrequest);
        assert s_readdata = x"12" report "write unsuccessful" severity error;

-- compulsary miss  w & !v & t & !d
-- write 14 to address 0. No offset. set index 00000. tag 000000.
-- will miss and replace word at set index
-- compare tags again, hit and perform the write. 
-- Dirty bit should be set.

        s_addr <= B"00000000000000000000000000000000"; 
        s_writedata <= X"14";
        s_write <= '1';
		  s_read <= '0';

        wait until rising_edge(m_waitrequest);
        assert m_readdata = x"0" report "write unsuccessful" severity error;
		  
		  wait for clk_period;
        
        wait until rising_edge(s_waitrequest);
        assert s_readdata = x"14" report "write unsuccessful" severity error;
     
-- w & v & t & d
-- write hit. old cache value overwritten.
-- dirty bit set 
		  s_addr <= B"00000000000000000000000000001000"; 
        s_writedata <= X"10";
        s_write <= '1';

        wait until rising_edge(s_waitrequest);
       
        assert s_readdata = x"10" report "write unsuccessful" severity error;
        
       
		  
-- w & v & !t & d
-- miss, tags do not match. old cache value written to MM. tag =1.
-- New indexed block fetched to $ from MM, then overwritten to writedata, dirty bit set.

		  s_addr <= B"00000000000000000000000010011001"; 
        s_writedata <= X"5";
        s_write <= '1';
		  s_read <= '0';

        wait until rising_edge(m_waitrequest);
        assert m_readdata = x"10" report "write unsuccessful" severity error;
		  
		  wait for clk_period;
        
        wait until rising_edge(s_waitrequest);
        assert s_readdata = x"5" report "write unsuccessful" severity error;
		  

-- r & v & t & d
-- hit, tags match.
      
		
		  s_addr <= B"00000000000000000000000010011001"; 
        s_write <= '0';
		  s_read <= '1';
        
        wait until rising_edge(s_waitrequest);
        assert s_readdata = x"5" report "write unsuccessful" severity error;
		  
		  wait for clk_period;
		 
-- r & v & !t & d
-- miss, tags do not match. old cache value written to MM.
-- block is evicted for new block with tag 2. This location should be empty.
      
		
		  s_addr <= B"00000000000000000000000110011001"; 
        s_write <= '0';
		  s_read <= '1';
        
		  wait until rising_edge(m_waitrequest);
        assert m_writedata = x"5" report "read unsuccessful" severity error;
		  
		  wait for clk_period;
		  
        wait until rising_edge(s_waitrequest);
        assert s_readdata = x"0" report "read unsuccessful" severity error;
	
-- r & v & t & !d
-- hit. 

		  s_addr <= B"00000000000000000000001010011001"; 
        s_write <= '0';
		  s_read <= '1';
        
		  wait until rising_edge(s_waitrequest);
        assert s_readdata = x"0"  report "read unsuccessful" severity error;
		  
		  wait for clk_period;
		  
-- r & !v & !t & !d
-- miss. Nothing at 11110. tag is not 3. Clean. allocates MM block to cache.

		  s_addr <= B"00000000000000000000001011111001"; 
        s_write <= '0';
		  s_read <= '1';
        
		  wait until rising_edge(s_waitrequest);
        assert s_readdata = x"0" report "read unsuccessful" severity error;
		  
		  wait for clk_period;
		  
-- r & !v & t & !d
-- miss. Nothing at 11111. tag is 0. Clean. allocates MM block to cache.

		  s_addr <= B"00000000000000000000000001111101"; 
        s_write <= '0';
		  s_read <= '1';
        
		  wait until rising_edge(s_waitrequest);
        assert s_readdata = x"0" report "read unsuccessful" severity error;
		  
		  wait for clk_period;
		  
-- r & !v & t & !d
-- miss. Nothing at 11111. tag is 0. Clean. allocates MM block to cache.

		  s_addr <= B"00000000000000000000000001111101"; 
        s_write <= '0';
		  s_read <= '1';
        
		  wait until rising_edge(s_waitrequest);
        assert s_readdata = x"0" report "read unsuccessful" severity error;
		  
		  wait for clk_period;

-- w & v & t & !d
-- write hit. old block value overwritten.
-- dirty bit set 
		  s_addr <= B"00000000000000000000000000001000"; 
        s_writedata <= X"101";
        s_write <= '1';
		  s_read <= '0';

        wait until rising_edge(s_waitrequest);
       
        assert s_readdata = x"101" report "write unsuccessful" severity error;
		  
-- w & v & !t & !d
-- write 31 to address 11111110. offset 3. set index 11110. tag 000111 does not match
-- will miss and replace word at set index from MM.
-- compare tags again, hit and perform the write. 
-- Dirty bit should be set.

        s_addr <= B"00000000000000000000001111111011"; 
        s_writedata <= X"31";
        s_write <= '1';
		  s_read <= '0';

        wait until rising_edge(m_waitrequest);
        assert m_readdata = x"0" report "write unsuccessful" severity error;
		  
		  wait for clk_period;
        
        wait until rising_edge(s_waitrequest);
        assert s_readdata = x"31" report "write unsuccessful" severity error;

	
end process;
	
end;