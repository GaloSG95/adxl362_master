-- Project      : 
-- Design       : 
-- Verification : 
-- Reviewers    : 
-- Module       : adxl362_master_tb.vhdl
-- Parent       : none
-- Children     : adxl362_master.vhdl
-- Description  : SPI communication testbench

library ieee;
use ieee.std_logic_1164.all;

entity adxl362_master_tb is
end entity adxl362_master_tb;

architecture adxl362_master_tb_arch of adxl362_master_tb is

  constant CLK_FREQ : real := 100.0e6;
  constant SPI_FREQ : real := 1.0e6;
  constant TVECTOR  : std_logic_vector(7 downto 0):= "11001010";
  constant PERIOD   : time := 1.0/CLK_FREQ*1.0e9 ns;
  CONSTANT POWER_CTRL_REG     : STD_LOGIC_VECTOR(7 DOWNTO 0) := "00101101";   -- h2D
  CONSTANT POWER_CTRL_MODE    : STD_LOGIC_VECTOR(7 DOWNTO 0) := "00100010";   -- h02 (Measurement mode)
  CONSTANT REG_WRITE_INST     : STD_LOGIC_VECTOR(7 DOWNTO 0) := "00001010";   -- h0A
  CONSTANT REG_READ_INST      : STD_LOGIC_VECTOR(7 DOWNTO 0) := "00001011";   -- h0B
  CONSTANT ADDR_X_DATA_REG    : STD_LOGIC_VECTOR(7 DOWNTO 0) := "00001000";   -- h08
  CONSTANT ZERO_PADDING       : std_logic_vector(7 downto 0) := "00000000";
  CONSTANT FULL_CONF_MESSAGE  : STD_LOGIC_VECTOR(23 downto 0) := REG_WRITE_INST & POWER_CTRL_REG & POWER_CTRL_MODE;
  CONSTANT READ_REG_MESAGE    : STD_LOGIC_VECTOR(15 downto 0) := REG_READ_INST & ADDR_X_DATA_REG;
  component adx362_master is
    port (  clk     : in    std_logic;
            rst     : in    std_logic;
            xdout   : out   std_logic_vector(7 downto 0);
            xvalid  : out   std_logic;
            cs      : out   std_logic;
            mosi    : out   std_logic;
            miso    : in    std_logic;
            sclk    : out   std_logic);
  end component;

  signal clk      : std_logic := '0';
  signal rst      : std_logic;
  signal xdout    : std_logic_vector(7 downto 0);
  signal xvalid   : std_logic;
  signal cs       : std_logic;
  signal mosi     : std_logic;
  signal miso     : std_logic;
  signal shutdown : std_logic;
  signal sclk     : std_logic;

begin

  dut : adx362_master
    port map(   clk     => clk, 
                rst     => rst,
                xdout   => xdout,
                xvalid  => xvalid,
                cs      => cs,  
                mosi    => mosi,
                miso    => miso,
                sclk    => sclk);

  clk <= not clk after PERIOD/2.0;

  reset_process : process
  begin
    rst <= '1';
    wait for PERIOD;
    rst <= '0';
    wait;
  end process;

  -- Timing checks, see adxl362 data sheet.
  t_HI_proc : process(sclk)
  begin
    if falling_edge(sclk) then
      assert sclk'delayed'stable(50 ns) report "Clock High Time < 50 ns" severity warning;
    end if;
  end process t_HI_proc;

  t_LO_proc : process(sclk)
  begin
    if rising_edge(sclk) then
      assert sclk'delayed'stable(50 ns) report "Clock Low Time < 50 ns" severity warning;
    end if;
  end process t_LO_proc;

  t_SU_proc : process (sclk)
  begin
    if rising_edge(sclk) then
      assert mosi'stable(20 ns) report "Data Input Setup Time < 20 ns" severity warning;
    end if;
  end process t_SU_proc;

  t_HD_proc : process
  begin
    wait until rising_edge(sclk);
    wait for 20 ns;
    assert mosi'stable(20 ns) report "Data Input Hold Time < 20 ns" severity warning;
  end process t_HD_proc;

  -- Receive data and compare to transmitted data
  data_verification_proc : process
    variable rmessage : std_logic_vector(23 downto 0):=(others => '0');
  begin
    miso <= '0';
    wait until falling_edge(cs);

    
    for idx in 23 downto 0 loop
      wait until rising_edge(sclk);
      rmessage := rmessage(22 downto 0) & mosi;
    end loop;

    assert rmessage = FULL_CONF_MESSAGE report "WRONG CONFIGURATION COMMAND" severity warning;

    for READ_REQ_N in 0 to 1 loop -- repeat 2 times
      wait until falling_edge(cs);
      for idx in 15 downto 0 loop
        wait until rising_edge(sclk);
        rmessage := rmessage(22 downto 0) & mosi;
      end loop;
    
      assert rmessage(15 downto 0) = READ_REG_MESAGE report "WRONG READ REQUEST" severity warning;

      for idx in 7 downto 0 loop
        wait until falling_edge(sclk);
        miso <= TVECTOR(idx);
      end loop;

      wait until rising_edge(xvalid);
      assert xdout = TVECTOR report "WROND XDATA" severity warning;
      assert cs = '1' report "CS NOT SET TO HIGH" severity warning;
    end loop;
    -- Force testbench to stop when the transmission is finished.
    report "Testbench finished!" severity failure;
  end process data_verification_proc;

end architecture adxl362_master_tb_arch;