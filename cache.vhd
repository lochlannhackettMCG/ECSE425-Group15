library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cache is
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
end cache;

architecture arch of cache is

-- declare signals here
	TYPE data IS ARRAY(127 downto 0) OF STD_LOGIC_VECTOR(31 DOWNTO 0);
   TYPE tags IS ARRAY(31 downto 0) OF STD_LOGIC_VECTOR(5 DOWNTO 0);
-- TYPE flags IS STD_LOGIC_VECTOR(31 DOWNTO 0);
   TYPE state IS (idle, write_hit, read_hit, write_miss, read_miss, write_back, write_allocate, replacement, done);
 
-- values stored in cache
	SIGNAL cache: data;
	SIGNAL valid: STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL dirty: STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL tag: tags;
  
-- fsm state
	SIGNAL current_state: state;
	SIGNAL request_count: integer;
	SIGNAL success_count: integer;
	SIGNAL read_write: STD_LOGIC;
  
-- intermediary vectors
	SIGNAL v_word_index: STD_LOGIC_VECTOR(1 downto 0);
	SIGNAL v_current_tag: STD_LOGIC_VECTOR(5 downto 0);
	SIGNAL v_block_index_cache: STD_LOGIC_VECTOR(4 downto 0);
    
  -- intermediary integers
	SIGNAL s_word_index: integer;
	SIGNAL s_block_index_cache: integer;
 
begin
 
  comm: process (clock, reset)
  begin
    
      -- logic vectors
      v_word_index <= s_addr(3 downto 2);
      v_current_tag <= s_addr(8 downto 4);
      v_block_index_cache <= s_addr(14 downto 9);
      
      -- integers
      s_word_index <= to_integer(unsigned(v_word_index));
      s_block_index_cache <= to_integer(unsigned(v_block_index_cache));
      
      -- if reset, return to idle
      if reset'event and reset = '1' then
          current_state <= idle;
          s_waitrequest <= '1';
          
      elsif clock'event and clock = '1' then
 
        case current_state is
        
            when idle =>
            
              s_waitrequest <= '1';
 
              if s_read = '1' then
              
                read_write <= '0';
              
                if valid(s_block_index_cache) and tag(s_block_index_cache) = v_current_tag then
                    current_state <= read_hit;
                else
                    current_state <= read_miss;
                end if;
 
              elsif s_write = '1' then
              
                read_write <= '1';
              
                if valid(s_block_index_cache) and tag(s_block_index_cache) = current_tag then
                    current_state <= write_hit;
                else
                    current_state <= write_miss;
                end if;
 
              end if;
              
            when read_hit =>
            
                s_waitrequest <= '0';
                current_state <= done;
            
            when write_hit =>
                
                s_waitrequest <= '0';
                
                -- set dirty
                dirty(s_block_index_cache) <= '1';
                
                -- add transition to read and write?
                current_state <= done;
                
            when read_miss =>
                
                -- write-back
                if dirty(s_block_index_cache) = '1' then
                    current_state <= write_back;
                else
                  current_state <= replacement;
                end if;
                
            when write_miss =>
                
                if dirty(s_block_index_cache) = '1' then
                    current_state <= write_back;
                else
                  current_state <= write_allocate;
                end if;
                
            when write_back =>
            
                if m_waitrequest = '1' and success_count = request_count then 
 
                  m_addr <= to_integer(unsigned(tag(s_block_index_cache) & v_block_index_cache & std_logic_vector(to_unsigned(request_count, 2)) & "00"));
                  m_writedata <= cache(s_block_index_cache)(request_count);
                  m_write <= '1';
 
                  request_count <= request_count + 1;
                 
                elsif m_waitrequest = '0' and not(request_count = 0) then -- change this
                
                    success_count <= request_count;
                    
                    if success_count = 4 then
 
                      success_count <= 0;
                      request_count <= 0;           
                      dirty(s_block_index_cache) <= '0';
 
                      if reading_writing = '0' then
                          current_state <= read_miss;
                      else
                          current_state <= write_miss;
                      end if;
 
                    end if;
                end if;
                
              when write_allocate =>
            
                if m_waitrequest = '1' and success_count = request_count then 
 
                  m_addr <= to_integer(unsigned(tag(s_block_index_cache) & v_block_index_cache & std_logic_vector(to_unsigned(request_count, 2)) & "00"));
                  m_read <= '1';
 
                  request_count <= request_count + 1;
                 
                elsif m_waitrequest = '0' and not(request_count = 0) then -- change this
                
                    success_count <= request_count;
                    
                    cache(s_block_index_cache)(request_count-1) := m_readdata;
                    
                    if success_count = 4 then
 
                      success_count <= 0;
                      request_count <= 0;
 
                      current_state <= write_hit;
                      
                    end if;
                end if;
                
                when replacement =>
                  if m_waitrequest = '1' and success_count = request_count then 
 
                    m_addr <= to_integer(unsigned(tag(s_block_index_cache) & v_block_index_cache & std_logic_vector(to_unsigned(request_count, 2)) & "00"));
                    m_read <= '1';
 
                    request_count <= request_count + 1;
 
                  elsif m_waitrequest = '0' and not(request_count = 0) then
 
                      success_count <= request_count;
 
                      cache(s_block_index_cache)(request_count-1) := m_readdata;
 
                      if success_count = 4 then
 
                        success_count <= 0;
                        request_count <= 0;
 
                        current_state <= write_hit;
 
                      end if;
                  end if;
                
            when done =>
            
                if read_write = '1' then
                    -- write in cache
                    cache(s_block_index_cache)(s_word_index) <= s_writedata;
                else
                    s_readdata <= cache(s_block_index_cache)(s_word_index);
                    
                current_state <= idle;
					 end if;
 
          end case;
     end if;
  end process;
 
end arch;