using Flexpart

@testset "Miscellaneous" begin
    FlexpartSim() do fpsim
        fpoptions = FlexpartOption(fpsim)

        Flexpart.set_specie!(fpoptions, "CH4")
        @test fpoptions["RELEASES"][:RELEASES_CTRL][:SPECNUM_REL].value == 26

        Flexpart.set_release_duration!(fpoptions["RELEASES"][:RELEASE][1], DateTime(2021,2,12), Dates.Second(120))
        @test fpoptions["RELEASES"][:RELEASE][:ITIME2].value == "000200"
    end
end